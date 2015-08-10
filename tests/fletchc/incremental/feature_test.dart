// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fletchc.test.feature_test;

import 'dart:io' hide
    exitCode,
    stderr,
    stdin,
    stdout;

import 'dart:io' as io;

import 'dart:async' show
    Completer,
    Future,
    Stream,
    StreamController,
    StreamIterator;

import 'dart:convert' show
    LineSplitter,
    UTF8,
    Utf8Decoder;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/incremental/scope_information_visitor.dart' show
    ScopeInformationVisitor;

import 'io_compiler_test_case.dart' show
    IoCompilerTestCase,
    IoInputProvider;

import 'compiler_test_case.dart' show
    CompilerTestCase;

import 'package:compiler/src/elements/elements.dart' show
    AbstractFieldElement,
    Element,
    FieldElement,
    FunctionElement,
    LibraryElement;

import 'package:compiler/src/dart2jslib.dart' show
    Compiler;

import 'package:fletchc/incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import 'package:fletchc/commands.dart' show
    Command,
    CommitChanges,
    CommitChangesResult,
    MapId;

import 'package:fletchc/compiler.dart' show
    FletchCompiler;

import 'package:fletchc/src/fletch_compiler.dart' as fletch_compiler_src;

import 'package:fletchc/fletch_system.dart';

import 'package:fletchc/commands.dart' as commands_lib;

import 'package:fletchc/session.dart' show
    CommandReader,
    Session;

import 'package:fletchc/src/fletch_backend.dart' show
    FletchBackend;

import 'package:fletchc/fletch_vm.dart' show
    FletchVm;

import 'program_result.dart';

import 'tests_with_expectations.dart' as tests_with_expectations;

typedef Future NoArgFuture();

Map<String, EncodedResult> tests = computeTests(tests_with_expectations.tests);

Future<Null> main(List<String> arguments) async {
  var testsToRun;
  if (arguments.isEmpty) {
    int skip = const int.fromEnvironment("skip", defaultValue: 0);
    testCount += skip;
    skippedCount += skip;

    testsToRun = tests.values.skip(skip);
    // TODO(ahe): Remove the following line, as it means only run the
    // first few tests.
    testsToRun = testsToRun.take(8);
  } else {
    testsToRun = arguments.map((String name) => tests[name]);
  }
  for (EncodedResult test in testsToRun) {
    await compileAndRun(true, test);
  }
  updateSummary();
}

int testCount = 1;

int skippedCount = 0;

int updateFailedCount = 0;

bool verboseStatus = const bool.fromEnvironment("verbose", defaultValue: false);

void updateSummary() {
  print(
      "\n\nTest ${testCount - 1} of ${tests.length} "
      "($skippedCount skipped, $updateFailedCount failed).");
}

compileAndRun(bool useFletchSystem, EncodedResult encodedResult) async {
  testCount++;

  updateSummary();
  List<ProgramResult> programs = encodedResult.decode();

  // The first program is compiled "fully". There rest are compiled below
  // as incremental updates to this first program.
  ProgramResult program = programs.first;

  print("Full program #$testCount:");
  print(numberedLines(program.code));

  IoCompilerTestCase test =
      new IoCompilerTestCase(useFletchSystem, program.code);
  FletchDelta fletchDelta = await test.run();

  TestSession session = await runFletchVM(test, fletchDelta);

  await new Future(() async {
    for (String expected in program.messages) {
      Expect.isTrue(await session.stdoutIterator.moveNext());
      Expect.stringEquals(expected, session.stdoutIterator.current);
      print("Got expected output: ${session.stdoutIterator.current}");
    }

    int version = 2;
    for (ProgramResult program in programs.skip(1)) {
      print("Update:");
      print(numberedLines(program.code));

      IoInputProvider inputProvider =
          test.incrementalCompiler.inputProvider;
      Uri base = test.scriptUri;
      Map<String, String> code = program.code is String
          ? { 'main.dart': program.code }
          : program.code;
      Map<Uri, Uri> uriMap = <Uri, Uri>{};
      for (String name in code.keys) {
        Uri uri = base.resolve('$name?v${version++}');
        inputProvider.cachedSources[uri] = new Future.value(code[name]);
        uriMap[base.resolve(name)] = uri;
      }
      Future<FletchDelta> future = test.incrementalCompiler.compileUpdates(
          fletchDelta.system, uriMap, logVerbose: logger, logTime: logger);
      bool compileUpdatesThrew = false;
      future = future.catchError((error, trace) {
        String statusMessage;
        Future result;
        compileUpdatesThrew = true;
        if (program.compileUpdatesShouldThrow &&
            error is IncrementalCompilationFailed) {
          statusMessage = "Expected error in compileUpdates.";
          result = null;
        } else {
          statusMessage = "Unexpected error in compileUpdates.";
          result = new Future.error(error, trace);
        }
        print(statusMessage);
        return result;
      });
      fletchDelta = await future;
      if (program.compileUpdatesShouldThrow) {
        updateFailedCount++;
        Expect.isTrue(
            compileUpdatesThrew,
            "Expected an exception in compileUpdates");
        Expect.isNull(fletchDelta, "Expected update == null");
        break;
      }

      CommitChangesResult result = await session.applyDelta(fletchDelta);
      for (Command command in fletchDelta.commands) print(command);

      if (!result.successful) {
        print("The CommitChanges() command was not successful: "
              "${result.message}");
      }

      Expect.equals(result.successful, !program.commitChangesShouldFail,
                    result.message);

      if (result.successful) {
        // Set breakpoint in main in case main was replaced.
        await session.setBreakpoint(methodName: "main", bytecodeIndex: 0);
        // Restart the current frame to rerun main.
        await session.restart();
        // Step out of main to finish execution of main.
        await session.stepOut();

        for (String expected in program.messages) {
          Expect.isTrue(await session.stdoutIterator.moveNext());
          String actual = session.stdoutIterator.current;
          Expect.stringEquals(expected, actual);
          print("Got expected output: $actual");
        }

        // TODO(ahe): Enable SerializeScopeTestCase for multiple
        // parts.
        if (program.code is String) {
          await new SerializeScopeTestCase(
              program.code, test.incrementalCompiler.mainApp,
              test.incrementalCompiler.compiler).run();
        }
      }
    }

    // If everything went fine, we will try finishing the execution and do a
    // graceful shutdown.
    if (session.running) {
      // The session is still alive. Run to completion.
      var continueCommand = const commands_lib.ProcessContinue();
      print(continueCommand);

      // Wait for process termination.
      Command response = await session.runCommand(continueCommand);
      if (response is! commands_lib.ProcessTerminated) {
        // TODO(ahe): It's probably an instance of
        // commands_lib.UncaughtException, and if so, we should try to print
        // the stack trace.
        throw new StateError(
            "Expected ProcessTerminated, but got: $response");
      }
    }
    await session.runCommand(const commands_lib.SessionEnd());
    await session.shutdown();
  }).catchError(session.handleError);

  // TODO(ahe/kustermann/ager): We really need to distinguish VM crashes from
  // normal test failures. This information is based on exitCode and we need
  // to propagate the exitCode back to test.dart, so we can have Fail/Crash
  // outcomes of these tests.
  await session.waitForCompletion();

  Expect.equals(
      0, await session.exitCode, "Unexpected exit code from fletch VM");
}

class SerializeScopeTestCase extends CompilerTestCase {
  final String source;

  final String scopeInfo;

  final Compiler compiler = null; // TODO(ahe): Provide a copiler.

  SerializeScopeTestCase(
      this.source,
      LibraryElement library,
      Compiler compiler)
      : scopeInfo = computeScopeInfo(compiler, library),
        super(library.canonicalUri);

  Future run() {
    if (true) {
      // TODO(ahe): Remove this. We're temporarily bypassing scope validation.
      return new Future.value(null);
    }
    return loadMainApp().then(checkScopes);
  }

  void checkScopes(LibraryElement library) {
    var compiler = null;
    Expect.stringEquals(computeScopeInfo(compiler, library), scopeInfo);
  }

  Future<LibraryElement> loadMainApp() async {
    LibraryElement library =
        await compiler.libraryLoader.loadLibrary(scriptUri);
    if (compiler.mainApp == null) {
      compiler.mainApp = library;
    } else if (compiler.mainApp != library) {
      throw "Inconsistent use of compiler (${compiler.mainApp} != $library).";
    }
    return library;
  }

  static String computeScopeInfo(Compiler compiler, LibraryElement library) {
    ScopeInformationVisitor visitor =
        new ScopeInformationVisitor(compiler, library, 0);

    visitor.ignoreImports = true;
    visitor.sortMembers = true;
    visitor.indented.write('[\n');
    visitor.indentationLevel++;
    visitor.indented;
    library.accept(visitor, null);
    library.forEachLocalMember((Element member) {
      if (member.isClass) {
        visitor.buffer.write(',\n');
        visitor.indented;
        member.accept(visitor, null);
      }
    });
    visitor.buffer.write('\n');
    visitor.indentationLevel--;
    visitor.indented.write(']');
    return '${visitor.buffer}';
  }
}

void logger(x) {
  print(x);
}

String numberedLines(code) {
  if (code is! Map) {
    code = {'main.dart': code};
  }
  StringBuffer result = new StringBuffer();
  code.forEach((String fileName, String code) {
    result.writeln("==> $fileName <==");
    int lineNumber = 1;
    for (String text in splitLines(code)) {
      result.write("$lineNumber: $text");
      lineNumber++;
    }
  });
  return '$result';
}

List<String> splitLines(String text) {
  return text.split(new RegExp('^', multiLine: true));
}

Future<TestSession> runFletchVM(
    IoCompilerTestCase test,
    FletchDelta fletchDelta) async {
  TestSession session =
      await TestSession.spawnVm(test.incrementalCompiler.compiler);
  try {
    await session.applyDelta(fletchDelta);
    for (Command command in fletchDelta.commands) print(command);

    for (Command command in [
        // Turn on debugging.
        const commands_lib.Debugging(),
        const commands_lib.ProcessSpawnForMain()]) {
      print(command);
      await session.runCommand(command);
    }

    // Allow operations on internal frames.
    await session.toggleInternal();
    // Set breakpoint in main.
    await session.setBreakpoint(methodName: "main", bytecodeIndex: 0);
    // Run the program to hit the breakpoint in main.
    await session.debugRun();
    // Step out of main to finish execution of main.
    await session.stepOut();

    return session;
  } catch (error, stackTrace) {
    return session.handleError(error, stackTrace);
  }
}

class TestSession extends Session {
  final Process process;
  final StreamIterator stdoutIterator;
  final Stream<String> stderr;

  final List<Future> futures;

  final Future<int> exitCode;

  bool isWaitingForCompletion = false;

  TestSession(
      Socket vmSocket,
      FletchCompiler compiler,
      this.process,
      this.stdoutIterator,
      this.stderr,
      this.futures,
      this.exitCode)
  : super(vmSocket, compiler, null, null);

  /// Add [future] to this session.  All futures that can fail after calling
  /// [waitForCompletion] must be added to the session.
  void recordFuture(Future future) {
    futures.add(convertErrorToString(future));
  }

  void addError(error, StackTrace stackTrace) {
    recordFuture(new Future.error(error, stackTrace));
  }

  /// Waits for the VM to shutdown and any futures added with [add] to
  /// complete, and report all errors that occurred.
  Future waitForCompletion() async {
    if (isWaitingForCompletion) {
      throw "waitForCompletion called more than once.";
    }
    isWaitingForCompletion = true;
    // [stderr] and [iterator] (stdout) must have active listeners before
    // waiting for [futures] below to avoid a deadlock.
    Future<List<String>> stderrFuture = stderr.toList();
    Future<List<String>> stdoutFuture = (() async {
      List<String> result = <String>[];
      while (await stdoutIterator.moveNext()) {
        result.add(stdoutIterator.current);
      }
      return result;
    })();

    StringBuffer sb = new StringBuffer();
    int problemCount = 0;
    for (var error in await Future.wait(futures)) {
      if (error != null) {
        sb.writeln("Problem #${++problemCount}:");
        sb.writeln(error);
        sb.writeln("");
      }
    }
    List<String> stdoutLines = await stdoutFuture;
    List<String> stderrLines = await stderrFuture;
    if (!stdoutLines.isEmpty) {
      sb.writeln("Problem #${++problemCount}:");
      sb.writeln("Unexpected stdout from fletch-vm:");
      for (String line in stdoutLines) {
        sb.writeln(line);
      }
      sb.writeln("");
    }
    if (!stderrLines.isEmpty) {
      sb.writeln("Problem #${++problemCount}:");
      sb.writeln("Unexpected stderr from fletch-vm:");
      for (String line in stderrLines) {
        sb.writeln(line);
      }
      sb.writeln("");
    }
    if (problemCount > 0) {
      throw new StateError('Test has $problemCount problem(s). Details:\n$sb');
    }
  }

  static Future<String> convertErrorToString(Future future) {
    return future.then((_) => null).catchError((error, stackTrace) {
      return "$error\n$stackTrace";
    });
  }

  static Future<TestSession> spawnVm(
      fletch_compiler_src.FletchCompiler compiler) async {
    io.stderr.writeln("TestSession.spawnVm");
    String vmPath = compiler.fletchVm.toFilePath();
    FletchBackend backend = compiler.backend;

    List<Future> futures = <Future>[];
    void recordFuture(String name, Future future) {
      if (future != null) {
        futures.add(convertErrorToString(future));
      }
    }

    List<String> vmOptions = <String>[
        '-Xvalidate-heaps',
    ];

    print("Running '$vmPath ${vmOptions.join(" ")}'");
    FletchVm fletchVm = await FletchVm.start(vmPath, arguments: vmOptions);

    // Unlike [fletchvm.stdoutLines] and [fletchvm.stderrLines], their
    // corresponding controller cannot produce an error.
    StreamController<String> stdoutController = new StreamController<String>();
    StreamController<String> stderrController = new StreamController<String>();
    recordFuture("stdout", fletchVm.stdoutLines.listen((String line) {
      print('fletch_vm_stdout: $line');
      stdoutController.add(line);
    }).asFuture().whenComplete(stdoutController.close));
    recordFuture("stderr", fletchVm.stderrLines.listen((String line) {
      print('fletch_vm_stderr: $line');
      stderrController.add(line);
    }).asFuture().whenComplete(stderrController.close));

    Completer<int> exitCodeCompleter = new Completer<int>();

    // TODO(ahe): If the VM crashes on startup, this will never complete. This
    // makes this program hang forever. But the exitCode completer might
    // actually be ready to give us a crashed exit code. Exiting early with a
    // failure in case exitCode is ready before server.first or having a
    // timeout on server.first would be possible solutions.
    var vmSocket = await fletchVm.connect();
    recordFuture("vmSocket", vmSocket.done);

    TestSession session = new TestSession(
        vmSocket, compiler.helper, fletchVm.process,
        new StreamIterator(stdoutController.stream),
        stderrController.stream,
        futures, exitCodeCompleter.future);

    recordFuture("exitCode", fletchVm.exitCode.then((int exitCode) {
      print("VM exited with exit code: $exitCode.");
      exitCodeCompleter.complete(exitCode);
    }));

    return session;
  }

  Future handleError(error, StackTrace stackTrace) {
    addError(error, stackTrace);

    // We either failed before we got to start a process or there was an
    // uncaught exception in the program. If there was an uncaught exception
    // the VM is intentionally hanging to give the debugger a chance to inspect
    // the state at the point of the throw. Therefore, we explicitly have to
    // kill the VM process. Notice, it is important that we kill the VM before
    // we close the socket to it. Otherwise, the VM may write a message on
    // stderr claiming that the compiler died (due to the socket getting
    // closed).
    process.kill();

    // After the process has been killed, we need to close the socket and
    // discard any commands that may have arrived.
    recordFuture(process.exitCode.then((_) => kill()));

    return waitForCompletion();
  }
}

/// Invoked by ../../fletch_tests/fletch_test_suite.dart.
Future<Map<String, NoArgFuture>> listTests() {
  Map<String, NoArgFuture> result = <String, NoArgFuture>{};
  tests.forEach((String name, EncodedResult test) {
    result['incremental/encoded/$name'] = () => main(<String>[name]);
    result['incremental/deprecated/$name'] = () => compileAndRun(false, test);
  });
  return new Future<Map<String, NoArgFuture>>.value(result);
}
