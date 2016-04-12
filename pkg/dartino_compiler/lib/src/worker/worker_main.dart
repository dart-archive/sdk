// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.worker_isolate;

import 'dart:async' show
    Completer,
    EventSink,
    Future,
    Stream,
    StreamController,
    StreamIterator,
    StreamSubscription,
    StreamTransformer,
    ZoneSpecification,
    runZoned;

import 'dart:isolate' show
    ReceivePort,
    SendPort;

import '../hub/client_commands.dart' show
    ClientCommand,
    ClientCommandCode,
    CommandSender;

import '../diagnostic.dart' show
    DiagnosticKind,
    InputError;

import '../hub/exit_codes.dart' show
    COMPILER_EXITCODE_CRASH;

import '../verbs/options.dart' show
    isBatchMode;

// This class is used to send commands from the worker isolate back to the
// hub (main isolate).
// TODO(ahe): Send ClientCommands directly when they are canonicalized
// correctly, see issue 23244.
class HubCommandSender extends CommandSender {
  final SendPort port;

  HubCommandSender(this.port);

  void sendExitCode(int exitCode) {
    port.send([ClientCommandCode.ExitCode.index, exitCode]);
  }

  void sendDataCommand(ClientCommandCode commandCode, List<int> data) {
    port.send([commandCode.index, data]);
  }

  void sendClose() {
    port.send([ClientCommandCode.ClosePort.index, null]);
  }

  void sendEventLoopStarted() {
    port.send([ClientCommandCode.EventLoopStarted.index, null]);
  }
}

Future<Null> workerMain(SendPort port) async {
  ReceivePort receivePort = new ReceivePort();
  port.send(receivePort.sendPort);
  port = null;
  StreamIterator iterator = new StreamIterator(receivePort);
  while (await iterator.moveNext()) {
    if (isBatchMode) {
      receivePort.close();
    }
    await beginSession(iterator.current);
  }
}

Future<Null> beginSession(SendPort port) {
  ReceivePort receivePort = new ReceivePort();
  port.send([ClientCommandCode.SendPort.index, receivePort.sendPort]);
  return handleClient(port, receivePort);
}

Future<int> doInZone(void printLineOnStdout(line), Future<int> f()) {
  ZoneSpecification specification = new ZoneSpecification(
      print: (_1, _2, _3, String line) => printLineOnStdout(line));
  return runZoned(f, zoneSpecification: specification);
}

Future<Null> handleClient(SendPort clientOutgoing, ReceivePort clientIncoming) {
  WorkerSideTask task =
      new WorkerSideTask(clientIncoming, new HubCommandSender(clientOutgoing));

  return doInZone(task.printLineOnStdout, task.perform).then((int exitCode) {
    task.endTask(exitCode);
  });
}

/// Represents a task running in this worker isolate.
class WorkerSideTask {
  final ReceivePort clientIncoming;

  final HubCommandSender commandSender;

  final StreamController<ClientCommand> filteredIncomingCommands =
      new StreamController<ClientCommand>();

  final Completer<int> taskCompleter = new Completer<int>();

  List<String> receivedArguments;

  WorkerSideTask(this.clientIncoming, this.commandSender);

  void printLineOnStdout(String line) {
    commandSender.sendStdout("$line\n");
  }

  Stream<ClientCommand> buildIncomingCommandStream() {
    void handleData(List message, EventSink<ClientCommand> sink) {
      int code = message[0];
      var data = message[1];
      sink.add(new ClientCommand(ClientCommandCode.values[code], data));
    }
    StreamTransformer<List, ClientCommand> commandDecoder =
        new StreamTransformer<List, ClientCommand>.fromHandlers(
            handleData: handleData);
    return clientIncoming.transform(commandDecoder);
  }

  void handleIncomingCommand(ClientCommand command) {
    if (command.code == ClientCommandCode.PerformTask) {
      performTask(command.data).then(taskCompleter.complete);
    } else {
      filteredIncomingCommands.add(command);
    }
  }

  void handleError(error, StackTrace stackTrace) {
    filteredIncomingCommands.addError(error, stackTrace);
  }

  void handleDone() {
    filteredIncomingCommands.close();
  }

  Future<int> performTask(
      Future<int> task(
          CommandSender commandSender,
          StreamIterator<ClientCommand> commandIterator)) async {
    StreamIterator<ClientCommand> commandIterator =
        new StreamIterator<ClientCommand>(filteredIncomingCommands.stream);

    try {
      return await task(commandSender, commandIterator);
    } on InputError catch (error, stackTrace) {
      // TODO(ahe): Send [error] instead.
      commandSender.sendStderr("${error.asDiagnostic().formatMessage()}\n");
      if (error.kind == DiagnosticKind.internalError) {
        commandSender.sendStderr("$stackTrace\n");
        return COMPILER_EXITCODE_CRASH;
      } else {
        return 1;
      }
    }
  }

  Future<int> perform() {
    StreamSubscription<ClientCommand> subscription =
        buildIncomingCommandStream().listen(null);
    subscription
        ..onData(handleIncomingCommand)
        ..onError(handleError)
        ..onDone(handleDone);
    return taskCompleter.future;
  }

  void endTask(int exitCode) {
    clientIncoming.close();
    commandSender.sendExitCode(exitCode);
    commandSender.sendClose();
  }
}
