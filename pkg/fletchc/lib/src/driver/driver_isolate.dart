// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver_isolate;

import 'dart:io' hide
    exitCode,
    stderr,
    stdin,
    stdout;

import 'dart:async' show
    Future,
    StreamIterator,
    StreamSubscription,
    StreamTransformer,
    Zone,
    ZoneSpecification;

import 'dart:isolate' show
    ReceivePort,
    SendPort;

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    stringifyError;

import 'verbs.dart' show
    Verb,
    commonVerbs,
    uncommonVerbs;

const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

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
    beginSession(iterator.current);
  }
}

Future<Null> beginSession(SendPort port) async {
  ReceivePort receivePort = new ReceivePort();
  port.send([DriverCommand.SendPort.index, receivePort.sendPort]);
  handleClient(port, receivePort);
}

Future handleClient(SendPort sendPort, ReceivePort receivePort) async {
  CommandSender commandSender = new PortCommandSender(sendPort);

  StreamTransformer commandDecoder =
      new StreamTransformer.fromHandlers(handleData: (message, sink) {
        int code = message[0];
        var data = message[1];
        sink.add(new Command(DriverCommand.values[code], data));
      });

  StreamIterator<Command> commandIterator = new StreamIterator<Command>(
      receivePort.transform(commandDecoder));

  Command command;
  if (await commandIterator.moveNext()) {
    command = commandIterator.current;
  }
  if (command == null || command.code != DriverCommand.Arguments) {
    print("Expected arguments from clients but got: $command");
    // The client is misbehaving, shut it down now.
    commandSender.sendClose();
    return null;
  }

  // This is argv from a C/C++ program. The first entry is the program name
  // which isn't normally included in Dart arguments (as passed to main).
  List<String> arguments = command.data;
  String programName = arguments.first;
  String fletchVm = "$programName-vm";
  String verbName;
  if (arguments.length < 2) {
    verbName = 'help';
    arguments = <String>[];
  } else {
    verbName = arguments[1];
    arguments = arguments.skip(2).toList();
  }
  Verb verb = commonVerbs[verbName];
  if (verb == null) {
    verb = uncommonVerbs[verbName];
  }
  if (verb == null) {
    commandSender.sendStderr("Unknown argument: $verbName\n");
    verb = commonVerbs['help'];
  }

  ZoneSpecification specification =
      new ZoneSpecification(print: (_1, _2, _3, String line) {
        commandSender.sendStdout('$line\n');
      },
      handleUncaughtError: (_1, _2, _3, error, StackTrace stackTrace) {
        String message =
            "\n\nExiting due to uncaught error.\n"
            "${stringifyError(error, stackTrace)}";
        Zone.ROOT.print(message);
        commandSender.sendStderr('$message\n');
        exit(1);
      });

  int exitCode = await Zone.current.fork(specification: specification).run(
      () async {
        try {
          return await verb.perform(
              fletchVm,
              arguments,
              commandSender,
              commandIterator);
        } catch (error, stackTrace) {
          String message =
              "\n\nExiting due to uncaught error.\n"
              "${stringifyError(error, stackTrace)}";
          Zone.ROOT.print(message);
          commandSender.sendStderr('$message\n');
          return DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        }
      });

  commandSender.sendExitCode(exitCode);

  commandIterator.cancel();

  commandSender.sendClose();

  receivePort.close();
}
