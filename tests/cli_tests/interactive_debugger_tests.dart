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
    Directory,
    Process,
    ProcessSignal;

import 'package:expect/expect.dart' show
    Expect;

import 'cli_tests.dart' show
    Test,
    TestContext,
    SessionTestContext,
    thisDirectory,
    dartinoVmBinary;

import 'prompt_splitter.dart' show
    PromptSplitter;

import 'package:dartino_compiler/src/hub/exit_codes.dart' show
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION,
    COMPILER_EXITCODE_CRASH;

import 'package:dartino_compiler/dartino_vm.dart' show DartinoVm;

/// Temporary directory for test output.
///
/// Snapshots will be put here.
const String tempTestOutputDirectory =
    const String.fromEnvironment("test.dart.temp-dir");

final List<Test> tests = <Test>[
  interrupt,
  listProcesses,
  relativePath,
  stepInLoop,
  rerunThrowingProgram,
];

final List<Test> snapshotTests = <Test>[
  debuggingFromSnapshot,
];

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var result = <String, NoArgFuture>{};
  for (Test test in tests) {
    // TODO(sigurdm) Run all tests both via session and snapshot.
    result["cli_debugger_tests/${test.name}"] =
        () => test.run(new BuildViaSessionTestContext());
  }
  for (Test test in tests) {
    result["cli_debugger_tests_snapshot/${test.name}"] =
        () => test.run(new SnapshotTestcontext());
  }
  return result;
}

abstract class InteractiveDebuggerTestContext extends SessionTestContext {
  Process process;
  StreamIterator out;
  StreamIterator err;

  Future<Null> setup(Test test) async {
    super.setup(test);
    await setupProcess();

    assert(process != null);
    out = new StreamIterator(
        process.stdout.transform(UTF8.decoder).transform(new PromptSplitter()));
    err = new StreamIterator(
        process.stderr.transform(UTF8.decoder).transform(new LineSplitter()));

    await expectPrompt("Debug header");
    await runCommandAndExpectPrompt("t testing");
  }

  /// Initializes a debugging process, and assign it to [process].
  Future<Null> setupProcess();

  Future<Null> tearDown() async {
    await tearDownProcess();
    await super.tearDown();
  }

  Future<Null> tearDownProcess() async {
    if (process != null) {
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
    List errors = [];

    Future collectError(Future f) {
      return f.catchError((e, s) {
        errors.add([e, s]);
      });
    }

    await Future.wait([
      collectError(expectClosed(out, "stdout")),
      collectError(expectClosed(err, "stderr")),
      collectError(process.stdin.done),
      collectError(process.exitCode.then((int actualExitCode) {
        Expect.equals(exitCode, actualExitCode, "Did not exit as expected");
      })),
    ]);
    if (errors.isNotEmpty) {
      if (errors.length == 1) {
        return new Future.error(errors.single[0], errors.single[1]);
      } else {
        throw errors;
      }
    }
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
      List<String> output = new List<String>();
      do {
        print("Unexpected content on $name: ${iterator.current}");
        output.add(iterator.current);
      } while (await iterator.moveNext());
      Expect.fail(
          "Expected $name stream to be empty, found '${output.join()}'");
    }
  }

  Future<Null> runCommandAndExpectPrompt(String command) async {
    await runCommand(command);
    await expectPrompt("Expected prompt for '$command'");
  }
}

class BuildViaSessionTestContext extends InteractiveDebuggerTestContext {
  Future<Null> setupProcess() async {
    process = await dartino(["debug", test.filePath],
        workingDirectory: test.workingDirectory);
    assert(process != null);
  }
}

class SnapshotTestcontext extends InteractiveDebuggerTestContext {
  DartinoVm vm;

  Future<Null> setupProcess() async {
    Uri snapshotDir =
        Uri.base.resolve("$tempTestOutputDirectory/cli_tests/${test.name}/");

    new Directory(snapshotDir.toFilePath()).create(recursive: true);
    String snapshotPath = snapshotDir.resolve("out.snapshot").toFilePath();

    // Build a snapshot.
    Process export = await dartino(
        ["export", test.filePath, "to", "file", snapshotPath],
        workingDirectory: test.workingDirectory);

    Expect.equals(0, await export.exitCode);

    // Start an interactive vm from a snapshot.
    vm = await DartinoVm.start(
        dartinoVmBinary.toFilePath(),
        arguments: ['--interactive', snapshotPath]);

    // Attach to that VM
    Process attach =
        await dartino(["attach", "tcp_socket", "localhost:${vm.port}"]);
    Expect.equals(0, await attach.exitCode);

    // Run the debugger.
    process = await dartino(["debug", test.filePath, "with", snapshotPath],
        workingDirectory: test.workingDirectory);
  }

  tearDownProcess() async {
    await vm.process.kill();
    await super.tearDownProcess();
  }
}

Test interrupt = new Test("debugger_interrupt",
    (InteractiveDebuggerTestContext context) async {
  await context.runCommand("r");
  await context.interrupt();
  await context.quitWithoutError();
});

Test listProcesses = new Test("debugger_list_processes",
    (InteractiveDebuggerTestContext context) async {
  await context.runCommandAndExpectPrompt("b resumeChild");
  await context.runCommandAndExpectPrompt("r");
  await context.runCommandAndExpectPrompt("lp");
  await context.runCommandAndExpectPrompt("c");
  await context.runCommandAndExpectPrompt("lp");
  await context.runCommandAndExpectPrompt("c");
  await context.expectExitCode(0);
});

Test relativePath = new Test("debugger_relative_file_reference",
    (InteractiveDebuggerTestContext context) async {
  await context.runCommandAndExpectPrompt("bf ${context.test.filePath} 13");
  await context.expectOut(
      "### set breakpoint id: '0' method: 'main' bytecode index: '0'");
  await context.runCommandAndExpectPrompt("r");
  await context.quitWithoutError();
}, // Working directory that is not the dartino-root directory.
    workingDirectory: "$thisDirectory/../",
// Relative reference to the test file.
    filepath: "cli_tests/debugger_relative_file_reference.dart");

Test stepInLoop = new Test("debugger_step_in_loop",
    (InteractiveDebuggerTestContext context) async {
  await context.runCommandAndExpectPrompt("b loop");
  await context.runCommandAndExpectPrompt("r");
  await context.runCommand("c");
  await context.interrupt();
  await context.runCommandAndExpectPrompt("sb");
  await context.runCommandAndExpectPrompt("nb");
  await context.runCommandAndExpectPrompt("s");
  await context.runCommandAndExpectPrompt("n");
  await context.quitWithoutError();
});

Test rerunThrowingProgram = new Test("debugger_rerun_throwing_program",
    (InteractiveDebuggerTestContext context) async {
  await context.runCommandAndExpectPrompt("r");  // throws uncaught exception
  await context.runCommandAndExpectPrompt("r");  // invalid command: use restart
  await context.expectOut(
      "### process already loaded, use 'restart' to run again");
  await context.quit();
  await context.expectExitCode(DART_VM_EXITCODE_UNCAUGHT_EXCEPTION);
});

Test debuggingFromSnapshot = new Test("debugging_from_snapshot",
    (InteractiveDebuggerTestContext context) async {
  await context.quitWithoutError();
}, filepath: "debugger_trivial.dart");

main(List<String> args) async {
  for (Test test in tests) {
    if (args.any((arg) => test.name.indexOf(arg) >= 0)) {
      await test.run(new BuildViaSessionTestContext());
    }
  }
}
