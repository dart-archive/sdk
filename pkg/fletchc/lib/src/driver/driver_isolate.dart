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

import '../../compiler.dart' show
    FletchCompiler;

import '../../commands.dart' as commands_lib;

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    handleSocketErrors,
    makeErrorHandler,
    stringifyError;

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

const fletchDriverSuffix = "_driver";

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

/* void */ isolateMain(SendPort port) async {
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
  port.send(receivePort.sendPort);
  handleClient(port, receivePort);
}

StreamSubscription handleSubscriptionErrors(
    StreamSubscription subscription,
    String name) {
  String info = "$name subscription";
  Zone.ROOT.print(info);
  return subscription
      ..onError(makeErrorHandler(info));
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

  await commandIterator.moveNext();
  Command command = commandIterator.current;
  if (command.code != DriverCommand.Arguments) {
    print("Expected arguments from clients but got: $command");
    // The client is misbehaving, shut it down now.
    commandSender.sendClose();
    return null;
  }

  // This is argv from a C/C++ program. The first entry is the program name
  // which isn't normally included in Dart arguments (as passed to main).
  List<String> arguments = command.data;
  String programName = arguments.first;
  String fletchVm = null;
  if (programName.endsWith(fletchDriverSuffix)) {
    fletchVm = programName.substring(
        0, programName.length - fletchDriverSuffix.length);
  }
  arguments = arguments.skip(1).toList();

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
          return await compileAndRun(
              fletchVm,
              arguments,
              commandSender,
              commandIterator);
        } catch (e) {
          print(e);
          return 255;
        }
      });

  commandSender.sendExitCode(exitCode);

  commandIterator.cancel();

  commandSender.sendClose();

  receivePort.close();
}

Future<int> compileAndRun(
    String fletchVm,
    List<String> arguments,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  String script;
  String snapshotPath;

  for (int i = 0; i < arguments.length; i++) {
    String argument = arguments[i];
    switch (argument) {
      case '-o':
      case '--out':
        snapshotPath = arguments[++i];
        break;

      default:
        if (script != null) throw "Unknown option: $argument";
        script = argument;
        break;
    }
  }

  if (script == null) throw "No script supplied";

  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(
          options: options, script: script, fletchVm: fletchVm,
          // TODO(ahe): packageRoot should be an option.
          packageRoot: "package/");
  bool compilerCrashed = false;
  List commands = await compiler.run().catchError((e, trace) {
    compilerCrashed = true;
    // TODO(ahe): Remove this catchError block when this bug is fixed:
    // https://code.google.com/p/dart/issues/detail?id=22437.
    print(e);
    print(trace);
    return [];
  });
  if (compilerCrashed) {
    return COMPILER_CRASHED;
  }

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
      '--port=${server.port}',
  ];

  var connectionIterator = new StreamIterator(server);

  String vmPath = compiler.fletchVm.toFilePath();

  if (compiler.verbose) {
    print("Running '$vmPath ${vmOptions.join(" ")}'");
  }
  Process vmProcess = await Process.start(vmPath, vmOptions);

  readCommands(commandIterator, vmProcess);

  // Notify controlling isolate (driver_main) that the event loop
  // [readCommands] has been started, and commands like DriverCommand.Signal
  // will be honored.
  commandSender.sendEventLoopStarted();

  StreamSubscription vmStdoutSubscription = handleSubscriptionErrors(
      vmProcess.stdout.listen(commandSender.sendStdoutBytes), "vm stdout");
  StreamSubscription vmStderrSubscription = handleSubscriptionErrors(
      vmProcess.stderr.listen(commandSender.sendStderrBytes), "vm stderr");

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = handleSocketErrors(connectionIterator.current, "vmSocket");
  server.close();

  vmSocket.listen(null).cancel();
  commands.forEach((command) => command.addTo(vmSocket));

  if (snapshotPath == null) {
    const commands_lib.ProcessSpawnForMain().addTo(vmSocket);
    const commands_lib.ProcessRun().addTo(vmSocket);
  } else {
    new commands_lib.WriteSnapshot(snapshotPath).addTo(vmSocket);
  }

  vmSocket.close();

  int exitCode = await vmProcess.exitCode;

  await vmProcess.stdin.close();
  await vmStdoutSubscription.cancel();
  await vmStderrSubscription.cancel();

  if (exitCode != 0) {
    print("Non-zero exit code from '$vmPath' ($exitCode).");
  }

  return exitCode;
}

Future<Null> readCommands(
    StreamIterator<Command> commandIterator,
    Process vmProcess) async {
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Stdin:
        if (command.data.length == 0) {
          await vmProcess.stdin.close();
        } else {
          vmProcess.stdin.add(command.data);
        }
        break;

      case DriverCommand.Signal:
        int signalNumber = command.data;
        Process.runSync("kill", ["-$signalNumber", "${vmProcess.pid}"]);
        break;

      default:
        Zone.ROOT.print("Unexpected command from client: $command");
    }
  }
}
