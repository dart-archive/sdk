// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;

import 'dart:async';
import 'dart:io';

import 'compiler.dart' show
    FletchCompiler;

import 'session.dart';

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

main(List<String> arguments) async {
  String script;
  String snapshotPath;
  bool debugging = false;
  bool testDebugger = false;

  for (int i = 0; i < arguments.length; i++) {
    String argument = arguments[i];
    switch (argument) {
      case '-o':
      case '--out':
        snapshotPath = arguments[++i];
        break;

      case '-d':
      case '--debug':
        debugging = true;
        break;

      case '--test-debugger':
        testDebugger = true;
        break;

      default:
        if (script != null) throw "Unknown option: $argument";
        script = argument;
        break;
    }
  }

  if (script == null) throw "No script supplied";

  exitCode = COMPILER_CRASHED;

  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  // TODO(ajohnsen): packageRoot should be a command line argument.
  FletchCompiler compiler = new FletchCompiler(
      options: options,
      script: script,
      packageRoot: "package/");
  List commands = await compiler.run();

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
      '--port=${server.port}',
  ];

  var connectionIterator = new StreamIterator(server);

  String vmPath = compiler.fletchVm.toFilePath();

  if (compiler.verbose) {
    print("Running '$vmPath ${vmOptions.join(" ")}'");
  }
  var vmProcess = await Process.start(vmPath, vmOptions);

  vmProcess.stdout.listen(stdout.add);
  vmProcess.stderr.listen(stderr.add);

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = connectionIterator.current;
  server.close();

  commands.forEach((command) => command.addTo(vmSocket));

  var session = new Session(vmSocket, compiler);

  if (snapshotPath != null) {
    session.writeSnapshot(snapshotPath);
  } else if (debugging) {
    if (testDebugger) {
      await session.testDebugStepToCompletion();
    } else {
      await session.debug();
    }
  } else {
    session.run();
  }

  exitCode = await vmProcess.exitCode;
  if (exitCode != 0) {
    print("Non-zero exit code from '$vmPath' ($exitCode).");
  }
  if (exitCode < 0) {
    // TODO(ahe): Is there a better value for reporting a VM crash?
    exitCode = COMPILER_CRASHED;
  }
}
