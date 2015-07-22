// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver_isolate;

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

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    stringifyError;

import '../diagnostic.dart' show
    DiagnosticKind,
    InputError,
    throwInternalError;

import 'exit_codes.dart' show
    COMPILER_EXITCODE_CRASH;

// TODO(ahe): Send DriverCommands directly when they are canonicalized
// correctly, see issue 23244.
class PortCommandSender extends CommandSender {
  final SendPort port;

  PortCommandSender(this.port);

  void sendExitCode(int exitCode) {
    port.send([DriverCommand.ExitCode.index, exitCode]);
  }

  void sendDataCommand(DriverCommand command, List<int> data) {
    port.send([command.index, data]);
  }

  void sendClose() {
    port.send([DriverCommand.ClosePort.index, null]);
  }

  void sendEventLoopStarted() {
    port.send([DriverCommand.EventLoopStarted.index, null]);
  }
}

Future<Null> isolateMain(SendPort port) async {
  ReceivePort receivePort = new ReceivePort();
  port.send(receivePort.sendPort);
  port = null;
  StreamIterator iterator = new StreamIterator(receivePort);
  while (await iterator.moveNext()) {
    await beginSession(iterator.current);
  }
}

Future<Null> beginSession(SendPort port) {
  ReceivePort receivePort = new ReceivePort();
  port.send([DriverCommand.SendPort.index, receivePort.sendPort]);
  return handleClient(port, receivePort);
}

Future<int> doInZone(void printLineOnStdout(line), Future<int> f()) {
  ZoneSpecification specification = new ZoneSpecification(
      print: (_1, _2, _3, String line) => printLineOnStdout(line));
  return runZoned(f, zoneSpecification: specification);
}

Future<Null> handleClient(SendPort clientOutgoing, ReceivePort clientIncoming) {
  WorkerSideTask task =
      new WorkerSideTask(clientIncoming, new PortCommandSender(clientOutgoing));

  return doInZone(task.printLineOnStdout, task.perform).then((int exitCode) {
    task.endTask(exitCode);
  });
}

/// Represents a task running in this worker isolate.
class WorkerSideTask {
  final ReceivePort clientIncoming;

  final CommandSender commandSender;

  final StreamController<Command> filteredIncomingCommands =
      new StreamController<Command>();

  final Completer<int> taskCompleter = new Completer<int>();

  List<String> receivedArguments;

  WorkerSideTask(this.clientIncoming, this.commandSender);

  void printLineOnStdout(String line) {
    commandSender.sendStdout("$line\n");
  }

  Stream<Command> buildIncomingCommandStream() {
    void handleData(List message, EventSink<Command> sink) {
      int code = message[0];
      var data = message[1];
      sink.add(new Command(DriverCommand.values[code], data));
    }
    StreamTransformer<List, Command> commandDecoder =
        new StreamTransformer<List, Command>.fromHandlers(
            handleData: handleData);
    return clientIncoming.transform(commandDecoder);
  }

  void handleIncomingCommand(Command command) {
    if (command.code == DriverCommand.PerformTask) {
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
          StreamIterator<Command> commandIterator)) async {
    StreamIterator<Command> commandIterator =
        new StreamIterator<Command>(filteredIncomingCommands.stream);

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
    StreamSubscription<Command> subscription =
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
