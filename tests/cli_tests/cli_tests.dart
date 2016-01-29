// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:io' show
    Process,
    ProcessResult;

import 'package:expect/expect.dart' show
    Expect;

import 'interactive_debugger_tests.dart' as
    interactiveDebuggerTests;

import 'rerun_throwing_program_test.dart' as
    rerunThrowingProgramTest;

import 'package:fletchc/src/hub/exit_codes.dart' show
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

/// Absolute path to the fletch executable.
final Uri fletchBinary = Uri.base.resolve("$buildDirectory/fletch");

final Uri thisDirectory = new Uri.directory("tests/cli_tests");

final List<CliTest> CLI_TESTS = <CliTest>[]
    ..addAll(interactiveDebuggerTests.tests)
    ..addAll(rerunThrowingProgramTest.tests)
    ..add(new NoSuchFile());

abstract class CliTest {
  final String name;
  String sessionName;

  CliTest(this.name);

  Future<Null> run();

  bool get sessionCreated => sessionName != null;

  Future<ProcessResult> createSession({String workingDirectory}) {
    assert(!sessionCreated);
    sessionName = "clitest-$name-$hashCode";
    return Process.run(
        fletchBinary.toFilePath(),
        ["create", "session", sessionName],
        workingDirectory: workingDirectory);
  }

  Future<Process> fletch(List<String> arguments,
                         {String workingDirectory}) async {
    if (!sessionCreated) {
      ProcessResult result = await createSession();
      Expect.equals(0, result.exitCode);
    }
    return Process.start(fletchBinary.toFilePath(), inSession(arguments),
        workingDirectory: workingDirectory);
  }

  Iterable<String> inSession(List<String> arguments) {
    return arguments..addAll(["in", "session", sessionName]);
  }
}

class NoSuchFile extends CliTest {
  NoSuchFile()
      : super("no_such_file");

  Future<Null> run() async {
    Process process = await fletch(["run", "no-such-file.dart"]);
    process.stdin.close();
    Future outClosed = process.stdout.listen(null).asFuture();
    await process.stderr.listen(null).asFuture();
    await outClosed;
    Expect.equals(DART_VM_EXITCODE_COMPILE_TIME_ERROR, await process.exitCode);
  }
}

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (CliTest test in CLI_TESTS) {
    tests["cli_tests/${test.name}"] = () => test.run();
  }
  return tests;
}
