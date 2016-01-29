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
  new RerunThrowingProgramTest(),
];

class RerunThrowingProgramTest extends CliTest {

  final Uri testFile = thisDirectory.resolve("throwing_program.dart");

  RerunThrowingProgramTest()
      : super("debugger_rerun_throwing");

  Future<Null> run() async {
    Process process = await fletch(["debug", testFile.toFilePath()]);

    StreamIterator out = new StreamIterator(
        process.stdout.transform(UTF8.decoder).transform(new PromptSplitter()));

    StreamIterator err = new StreamIterator(
        process.stderr.transform(UTF8.decoder).transform(new LineSplitter()));

    // Consume debug-shell header.
    Expect.isTrue(await out.moveNext(), "Debug header");

    // Invoke run. This does not return the prompt.
    process.stdin.writeln("r");

    // Expect the program throws an uncaught exception.
    Expect.isTrue(await out.moveNext(), "No uncaught exception");

    // Try running again and check valid error message.
    process.stdin.writeln("r");
    Expect.isTrue(await out.moveNext(), "No error message");
    Expect.equals(
        out.current, "### process already loaded, use 'restart' to run again");

    process.stdin.writeln("q");
    process.stdin.close();
    // We get exit code 255 (DART_VM_EXITCODE_UNCAUGHT_EXCEPTION).
    Expect.equals(255, await process.exitCode, "Failed to exit");

    // Check out and err are empty and closed.
    Expect.isFalse(await out.moveNext());
    Expect.isFalse(await err.moveNext());
  }
}
