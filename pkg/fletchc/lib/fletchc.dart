// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;

import 'dart:async';

import 'dart:io';

import 'compiler.dart' show
    FletchCompiler;

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

main(List<String> arguments) async {
  exitCode = COMPILER_CRASHED;

  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  // TODO(ajohnsen): packageRoot should be a command line argument.
  FletchCompiler compiler = new FletchCompiler(
      options: options,
      script: arguments.single,
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

  if (compilerCrashed) return;

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
      '--port=${server.port}',
      '-Xvalidate-stack',
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

  vmSocket.listen(null);
  commands.forEach((command) => command.addTo(vmSocket));
  vmSocket.close();

  exitCode = await vmProcess.exitCode;
  if (exitCode != 0) {
    print("Non-zero exit code from '$vmPath' ($exitCode).");
  }
  if (exitCode < 0) {
    // TODO(ahe): Is there a better value for reporting a VM crash?
    exitCode = COMPILER_CRASHED;
  }
}
