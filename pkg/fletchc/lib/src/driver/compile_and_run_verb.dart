// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.compile_and_run_verb;

import 'dart:async' show
    Completer,
    Future,
    StreamIterator,
    StreamSubscription,
    Zone;

import 'dart:io' show
    InternetAddress,
    Process,
    ServerSocket,
    Socket;

import '../../compiler.dart' show
    FletchCompiler,
    StringOrUri;

import '../../commands.dart' as commands_lib;

import '../../fletch_system.dart';

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    handleSocketErrors,
    makeErrorHandler;

import 'verbs.dart' show
    Verb;

const Verb compileAndRunVerb =
    const Verb(compileAndRun, documentation, requiresWorker: true);

const String documentation = """
   compile-and-run [options] dartfile
             Compile and run dartfile in a temporary session.  This is a
             provisionary feature that will be removed shortly.
""";

const COMPILER_CRASHED = 253;

Future<int> compileAndRun(
    String fletchVm,
    List<String> arguments,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
    // TODO(ahe): packageRoot should be an option.
    {@StringOrUri packageRoot: "package/"}) async {
  String script;
  String snapshotPath;
  String attachArgument;

  for (int i = 0; i < arguments.length; i++) {
    String argument = arguments[i];
    switch (argument) {
      case '-o':
      case '--out':
        snapshotPath = arguments[++i];
        break;

      case '-a':
      case '--attach':
        attachArgument = arguments[++i];
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
          packageRoot: packageRoot);
  bool compilerCrashed = false;
  FletchDelta fletchDelta = await compiler.run().catchError((e, trace) {
    compilerCrashed = true;
    // TODO(ahe): Remove this catchError block when this bug is fixed:
    // https://code.google.com/p/dart/issues/detail?id=22437.
    print(e);
    print(trace);
    return null;
  });
  if (compilerCrashed) {
    return COMPILER_CRASHED;
  }

  Process vmProcess;
  int exitCode = 0;
  Socket vmSocket;
  List futures = [];
  trackSubscription(StreamSubscription subscription, String name) {
    futures.add(doneFuture(handleSubscriptionErrors(subscription, name)));
  }
  if (attachArgument == null) {
    var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

    List<String> vmOptions = <String>[
        '--port=${server.port}',
      ];

    String vmPath = compiler.fletchVm.toFilePath();

    if (compiler.verbose) {
      print("Running '$vmPath ${vmOptions.join(" ")}'");
    }
    vmProcess = await Process.start(
        vmPath, vmOptions,
        environment: {'ASAN_OPTIONS': 'abort_on_error=1'});
    futures.add(vmProcess.exitCode.then((int value) {
      exitCode = value;
      if (exitCode != 0) {
        print("Non-zero exit code from '$vmPath' ($exitCode).");
      }
      server.close();
    }));

    readCommands(commandIterator, vmProcess);

    // Notify controlling isolate (driver_main) that the event loop
    // [readCommands] has been started, and commands like DriverCommand.Signal
    // will be honored.
    commandSender.sendEventLoopStarted();

    trackSubscription(
        vmProcess.stdout.listen(commandSender.sendStdoutBytes), "vm stdout");
    trackSubscription(
        vmProcess.stderr.listen(commandSender.sendStderrBytes), "vm stderr");

    try {
      vmSocket = await server.first;
    } catch (e) {
      // If this fails, the VM exited before it connected (the socket server is
      // closed above when the vmProcess.exitCode future completes).
      return exitCode;
    }
    vmSocket = handleSocketErrors(vmSocket, "vmSocket");
  } else {
    var address = attachArgument.split(":");
    String host = address[0];
    int port = int.parse(address[1]);
    print("Connecting to $host:$port");
    vmSocket = handleSocketErrors(await Socket.connect(host, port), "vmSocket");
  }

  trackSubscription(vmSocket.listen(null), "vmSocket");
  fletchDelta.commands.forEach((command) => command.addTo(vmSocket));

  if (snapshotPath == null) {
    const commands_lib.ProcessSpawnForMain().addTo(vmSocket);
    const commands_lib.ProcessRun().addTo(vmSocket);
  } else {
    new commands_lib.WriteSnapshot(snapshotPath).addTo(vmSocket);
  }

  vmSocket.close();

  if (vmProcess != null) {
    futures.add(vmProcess.stdin.close());
  }

  await Future.wait(futures);

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

StreamSubscription handleSubscriptionErrors(
    StreamSubscription subscription,
    String name) {
  String info = "$name subscription";
  Zone.ROOT.print(info);
  return subscription
      ..onError(makeErrorHandler(info));
}

Future doneFuture(StreamSubscription subscription) {
  var completer = new Completer();
  subscription.onDone(() => completer.complete());
  return completer.future;
}
