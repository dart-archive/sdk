// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future,
    StreamIterator;

import 'dart:convert' show
    LineSplitter,
    UTF8;

import 'dart:io' show
    Process,
    ProcessSignal;

import 'package:expect/expect.dart' show
    Expect;

import 'cli_tests.dart' show
    CliTest,
    thisDirectory;

import 'prompt_splitter.dart' show
    PromptSplitter;

import 'package:dartino_compiler/src/hub/exit_codes.dart' show
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;

final List<CliTest> tests = <CliTest>[
  new DebuggerInterruptTest(),
  new DebuggerListProcessesTest(),
  new DebuggerRelativeFileReferenceTest(),
  new DebuggerStepInLoopTest(),
  new DebuggerRerunThrowingProgramTest(),
];

abstract class InteractiveDebuggerTest extends CliTest {
  final String testFilePath;
  final String workingDirectory;
  Process process;
  StreamIterator out;
  StreamIterator err;

  InteractiveDebuggerTest(String name)
      : super(name),
        testFilePath = thisDirectory.resolve("$name.dart").toFilePath();

  Future<Null> internalRun();

  Future<Null> run() async {
    process = await dartino(["debug", testFilePath],
                           workingDirectory: workingDirectory);
    out = new StreamIterator(
      process.stdout.transform(UTF8.decoder).transform(new PromptSplitter()));
    err = new StreamIterator(
      process.stderr.transform(UTF8.decoder).transform(new LineSplitter()));
    try {
      await expectPrompt("Debug header");
      await internalRun();
    } finally {
      process.stdin.close();
      await out.cancel();
      await err.cancel();
    }
  }

  Future<Null> runCommand(String command) async {
    print("> $command");
    process.stdin.writeln(command);
  }

  Future<Null> interrupt() async {
    print("^\\");
    Expect.isTrue(process.kill(ProcessSignal.SIGQUIT), "Sent quit to process");
    // TODO(zerny): Make interrupt a first-class and ordered VM command.
    await new Future.delayed(const Duration(seconds: 1), () {
      Expect.isTrue(process.kill(ProcessSignal.SIGQUIT),
                    "Sent quit to process");
    });
    await expectPrompt("Interrupt expects to return prompt");
  }

  Future<Null> quitWithoutError() async {
    await quit();
    await expectExitCode(0);
  }

  Future<Null> quit() async {
    await runCommand("q");
    process.stdin.close();
  }

  Future<Null> expectExitCode(int exitCode) async {
    Future expectOutClosed = expectClosed(out, "stdout");
    await expectClosed(err, "stderr");
    await expectOutClosed;
    Expect.equals(exitCode, await process.exitCode,
        "Did not exit as expected");
  }

  Future<Null> expectPrompt(String message) async {
    Expect.isTrue(await out.moveNext(), message);
    if (out.current.isNotEmpty) print(out.current);
  }

  Future<Null> expectOut(String message) async {
    Expect.equals(message, out.current);
  }

  Future<Null> expectErr(String message) async {
    Expect.equals(message, err.current);
  }

  Future<Null> expectClosed(StreamIterator iterator, String name) async {
    if (await iterator.moveNext()) {
      do {
        print("Unexpected content on $name: ${iterator.current}");
      } while (await iterator.moveNext());
      Expect.fail("Expected $name stream to be empty");
    }
  }

  Future<Null> runCommandAndExpectPrompt(String command) async {
    await runCommand(command);
    await expectPrompt("Expected prompt for '$command'");
  }
}

class DebuggerInterruptTest extends InteractiveDebuggerTest {

  DebuggerInterruptTest()
      : super("debugger_interrupt");

  Future<Null> internalRun() async {
    await runCommand("r");
    await interrupt();
    await quitWithoutError();
  }
}

class DebuggerListProcessesTest extends InteractiveDebuggerTest {

  DebuggerListProcessesTest()
      : super("debugger_list_processes");

  Future<Null> internalRun() async {
    await runCommandAndExpectPrompt("b resumeChild");
    await runCommandAndExpectPrompt("r");
    await runCommandAndExpectPrompt("lp");
    await runCommandAndExpectPrompt("c");
    await runCommandAndExpectPrompt("lp");
    await runCommandAndExpectPrompt("c");
    await expectExitCode(0);
  }
}

class DebuggerRelativeFileReferenceTest extends InteractiveDebuggerTest {

  // Working directory that is not the dartino-root directory.
  final String workingDirectory = "$thisDirectory/../";

  // Relative reference to the test file.
  final String testFilePath = "cli_tests/debugger_relative_file_reference.dart";

  DebuggerRelativeFileReferenceTest()
      : super("debugger_relative_file_reference");

  Future<Null> internalRun() async {
    await runCommandAndExpectPrompt("bf $testFilePath 13");
    await expectOut(
        "breakpoint set: id: '0' method: 'main' bytecode index: '0'");
    await runCommandAndExpectPrompt("r");
    await quitWithoutError();
  }
}

class DebuggerStepInLoopTest extends InteractiveDebuggerTest {

  DebuggerStepInLoopTest()
      : super("debugger_step_in_loop");

  Future<Null> internalRun() async {
    await runCommandAndExpectPrompt("b loop");
    await runCommandAndExpectPrompt("r");
    await runCommand("c");
    await interrupt();
    await runCommandAndExpectPrompt("sb");
    await runCommandAndExpectPrompt("nb");
    await runCommandAndExpectPrompt("s");
    await runCommandAndExpectPrompt("n");
    await quitWithoutError();
  }
}

class DebuggerRerunThrowingProgramTest extends InteractiveDebuggerTest {

  DebuggerRerunThrowingProgramTest()
      : super("debugger_rerun_throwing_program");

  Future<Null> internalRun() async {
    await runCommandAndExpectPrompt("r");  // throws uncaught exception
    await runCommandAndExpectPrompt("r");  // invalid command: use restart
    await expectOut("### process already loaded, use 'restart' to run again");
    await quit();
    await expectExitCode(DART_VM_EXITCODE_UNCAUGHT_EXCEPTION);
  }
}

main(List<String> args) async {
  for (CliTest test in tests) {
    if (args.any((arg) => test.name.indexOf(arg) >= 0)) {
      await test.run();
    }
  }
}
