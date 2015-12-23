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

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

final String fletchBinary = "$buildDirectory/fletch";

final Uri thisDirectory = new Uri.directory("tests/cli_tests");

final List<CliTest> CLI_TESTS = <CliTest>[]
    ..addAll(interactiveDebuggerTests.tests)
    ..addAll(rerunThrowingProgramTest.tests);

abstract class CliTest {
  final String name;
  String sessionName;

  CliTest(this.name);

  Future<Null> run();

  bool get sessionCreated => sessionName != null;

  Future<ProcessResult> createSession() {
    assert(!sessionCreated);
    sessionName = "clitest-$name";
    return Process.run(fletchBinary, ["create", "session", sessionName]);
  }

  Future<Process> fletch(List<String> arguments) async {
    if (!sessionCreated) {
      ProcessResult result = await createSession();
      Expect.equals(0, result.exitCode);
    }
    return Process.start(fletchBinary, inSession(arguments));
  }

  Iterable<String> inSession(List<String> arguments) {
    return arguments..addAll(["in", "session", sessionName]);
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
