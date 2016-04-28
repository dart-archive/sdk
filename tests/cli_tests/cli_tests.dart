// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:io' show
    Process,
    ProcessResult,
    stdout;

import 'package:expect/expect.dart' show
    Expect;

import 'interactive_debugger_tests.dart' as
    interactiveDebuggerTests;

import 'package:dartino_compiler/src/hub/exit_codes.dart' show
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

/// Absolute path to the dartino executable.
final Uri dartinoBinary = Uri.base.resolve("$buildDirectory/dartino");
final Uri dartinoVmBinary = Uri.base.resolve("$buildDirectory/dartino-vm");

final Uri thisDirectory = new Uri.directory("tests/cli_tests");

abstract class TestContext {
  Test test;
  TestContext();

  Future<Null> setup(Test test);
  Future<Null> tearDown();

  // Run a dartino command.
  Future<Process> dartino(List<String> arguments, {String workingDirectory});
}

class SessionTestContext extends TestContext {
  String sessionName;

  SessionTestContext() : super();

  Future<Null> setup(Test test) async {
    this.test = test;
    ProcessResult result = await createSession();
    Expect.equals(0, result.exitCode);
  }

  Future<Null> tearDown() async {}

  bool get sessionCreated => sessionName != null;

  Future<ProcessResult> createSession({String workingDirectory}) {
    assert(!sessionCreated);
    sessionName = "clitest-${test.name}-$hashCode";
    return Process.run(
        dartinoBinary.toFilePath(),
        ["create", "session", sessionName],
        workingDirectory: workingDirectory);
  }

  Future<Process> dartino(List<String> arguments,
                         {String workingDirectory}) async {
    Process process =
        await Process.start(
            dartinoBinary.toFilePath(),
            inSession(arguments),
            workingDirectory: workingDirectory);
    process.stdin.done.catchError((e) {
      // Ignore errors. They are collected when the process is closed.
    });
    return process;
  }

  Iterable<String> inSession(List<String> arguments) {
    return [arguments, ["in", "session", sessionName]].expand((x) => x)
        .toList();
  }
}

typedef Future<Null> TestFunction(TestContext context);

class Test {
  final String name;
  final TestFunction runFunction;
  final String workingDirectory;
  final String filePath;

  Test(String name, this.runFunction,
      {String workingDirectory, String filepath})
      : name = name,
        filePath = filepath ?? "$name.dart",
        workingDirectory = workingDirectory ?? thisDirectory.toFilePath();

  Future<Null> run(TestContext context) async {
    try {
      await context.setup(this);
      await runFunction(context);
    } finally {
      await context.tearDown();
    }
  }
}

List<Test> cliTests = [
  new Test("no_such_file", (SessionTestContext context) async{
    Process process = await context.dartino(["run", "no-such-file.dart"]);
    process.stdin.close();
    Future outClosed = process.stdout.listen(null).asFuture();
    await process.stderr.listen(null).asFuture();
    await outClosed;
    Expect.equals(DART_VM_EXITCODE_COMPILE_TIME_ERROR, await process.exitCode);
  })
];

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (Test test in cliTests) {
    tests["cli_tests/${test.name}"] = () => test.run(new SessionTestContext());
  }
  tests.addAll(await interactiveDebuggerTests.listTests());
  return tests;
}
