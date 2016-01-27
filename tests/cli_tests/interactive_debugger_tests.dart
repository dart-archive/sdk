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

final List<CliTest> tests = <CliTest>[
  new DebuggerInterruptTest(),
  new DebuggerListProcessesTest(),
];

abstract class InteractiveDebuggerTest extends CliTest {
  final String testFilePath;
  Process process;
  StreamIterator out;
  StreamIterator err;

  InteractiveDebuggerTest(String name)
      : super(name),
        testFilePath = thisDirectory.resolve("$name.dart").toFilePath();

  Future<Null> internalRun();

  Future<Null> run() async {
    process = await fletch(["debug", testFilePath]);
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
    print("C-\\");
    Expect.isTrue(process.kill(ProcessSignal.SIGQUIT), "Sent quit to process");
  }

  Future<Null> quitWithoutError() async {
    await quit();
    await expectExitCode(0);
  }

  Future<Null> quit() async {
    process.stdin.writeln("q");
    process.stdin.close();
  }

  Future<Null> expectExitCode(int exitCode) async {
    Future expectOutClosed = expectClosed(out, 'stdout');
    await expectClosed(err, 'stderr');
    await expectOutClosed;
    Expect.equals(exitCode, await process.exitCode,
        "Did not exit as expected");
  }

  Future<Null> expectPrompt(String message) async {
    Expect.isTrue(await out.moveNext(), message);
    print(out.current);
  }

  Future<Null> expectClosed(StreamIterator iterator, String name) async {
    if (await iterator.moveNext()) {
      do {
        print("Unexpected content on $name: ${iterator.current}");
      } while (await iterator.moveNext());
      Expect.fail('Expected $name stream to be empty');
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
    await expectPrompt("Interrupt returns prompt");
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
