// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Provides a [Command] interface for interacting with a Fletch driver session.
///
/// Normally, this is used by test.dart, but is also has a [main] method that
/// makes it possible to run a test outside test.dart.
library test.fletch_session_command;

import 'dart:async' show
    Completer,
    EventSink,
    Future,
    Stream,
    StreamController,
    StreamTransformer,
    Timer;

import 'dart:collection' show
    Queue;

import 'dart:convert' show
    UTF8,
    LineSplitter;

import 'dart:io' show
    BytesBuilder,
    Platform,
    Process,
    ProcessSignal;

import 'test_runner.dart' show
    Command,
    CommandOutputImpl,
    TestCase;

import 'status_file_parser.dart' show
    Expectation;

import '../../../pkg/fletchc/lib/src/driver/exit_codes.dart' show
    COMPILER_EXITCODE_CRASH,
    DART_VM_EXITCODE_COMPILE_TIME_ERROR,
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;

import '../../../pkg/fletchc/lib/fletch_vm.dart' show
    FletchVm;

final Queue<int> sessions = new Queue<int>();

int sessionCount = 0;

int getAvailableSessionId() {
  if (sessions.isEmpty) {
    return sessionCount++;
  } else {
    return sessions.removeFirst();
  }
}

void returnSessionId(int id) {
  sessions.addLast(id);
}

class FletchSessionCommand implements Command {
  final String executable;
  final String script;
  final List<String> arguments;
  final Map<String, String> environmentOverrides;

  FletchSessionCommand(
      this.executable,
      this.script,
      this.arguments,
      this.environmentOverrides);

  String get displayName => "fletch_session";

  int get maxNumRetries => 0;

  String get reproductionCommand {
    return "${Platform.executable} -c "
        "tools/testing/dart/fletch_session_command.dart "
        "$executable $script ${arguments.join(' ')}";
  }

  Future<FletchTestCommandOutput> run(
      int timeout,
      bool verbose,
      {bool superVerbose: false}) async {
    if (arguments.length > 1) {
      String options = arguments
          .where((String argument) => argument != script)
          .join(' ');
      // TODO(ahe): Passing options to the incremental compiler isn't
      // trivial. We don't want to reset the compiler each time an option
      // changes. For example, when changing the package root, the compiler
      // should refresh all package files to see if they have changed.
      return compilerFail("Compiler options not implemented: $options");
    }

    FletchSessionHelper fletch =
        new FletchSessionHelper(
            getAvailableSessionId(), executable, environmentOverrides,
            verbose, superVerbose);

    Stopwatch sw = new Stopwatch()..start();
    int exitCode = COMPILER_EXITCODE_CRASH;
    try {
      await fletch.run(["create", "session", fletch.session]);
      try {
        await fletch.runInSession(["compile", "file", script]);
        String vmSocketAddress = await fletch.spawnVm();
        await fletch.runInSession(["attach", "tcp_socket", vmSocketAddress]);
        exitCode = await fletch.runInSession(["x-run"], checkExitCode: false);
      } finally {
        await fletch.run(["x-end", "session", fletch.session]);
        returnSessionId(fletch.sessionId);
        await fletch.shutdownVm(exitCode);
      }
    } on UnexpectedExitCode catch (error) {
      fletch.stderr.writeln("$error");
      exitCode = error.exitCode;
    }

    return new FletchTestCommandOutput(
        this, exitCode, false,
        fletch.combinedStdout, fletch.combinedStderr, sw.elapsed, -1);
  }

  FletchTestCommandOutput compilerFail(String message) {
    return new FletchTestCommandOutput(
        this, DART_VM_EXITCODE_COMPILE_TIME_ERROR, false, <int>[],
        UTF8.encode(message), const Duration(seconds: 0), -1);
  }

  String toString() => reproductionCommand;

  set displayName(_) => throw "not supported";

  get commandLine => throw "not supported";
  set commandLine(_) => throw "not supported";

  get outputIsUpToDate => throw "not supported";
}

class UnexpectedExitCode extends Error {
  final int exitCode;
  final String executable;
  final List<String> arguments;

  UnexpectedExitCode(this.exitCode, this.executable, this.arguments);

  String toString() {
    return "Non-zero exit code ($exitCode) from: "
        "$executable ${arguments.join(' ')}";
  }
}

class FletchTestCommandOutput extends CommandOutputImpl {
  FletchTestCommandOutput(
      Command command,
      int exitCode,
      bool timedOut,
      List<int> stdout,
      List<int> stderr,
      Duration time,
      int pid)
      : super(command, exitCode, timedOut, stdout, stderr, time, false, pid);

  Expectation decodeExitCode() {
    switch (exitCode) {
      case 0:
        return Expectation.PASS;

      case COMPILER_EXITCODE_CRASH:
        return Expectation.CRASH;

      case DART_VM_EXITCODE_COMPILE_TIME_ERROR:
        return Expectation.COMPILETIME_ERROR;

      case DART_VM_EXITCODE_UNCAUGHT_EXCEPTION:
        return Expectation.RUNTIME_ERROR;

      default:
        return Expectation.FAIL;
    }
  }

  Expectation result(TestCase testCase) {
    Expectation outcome = decodeExitCode();

    if (testCase.hasRuntimeError) {
      if (!outcome.canBeOutcomeOf(Expectation.RUNTIME_ERROR)) {
        if (outcome == Expectation.PASS) {
          return Expectation.MISSING_RUNTIME_ERROR;
        } else {
          return outcome;
        }
      }
    }

    if (testCase.hasCompileError) {
      if (!outcome.canBeOutcomeOf(Expectation.COMPILETIME_ERROR)) {
        if (outcome == Expectation.PASS) {
          return Expectation.MISSING_COMPILETIME_ERROR;
        } else {
          return outcome;
        }
      }
    }

    if (testCase.isNegative) {
      return outcome.canBeOutcomeOf(Expectation.FAIL)
          ? Expectation.PASS
          : Expectation.FAIL;
    }

    return outcome;
  }
}

Stream<List<int>> addPrefixWhenNotEmpty(
    Stream<List<int>> input,
    String prefix) async* {
  bool isFirst = true;
  await for (List<int> bytes in input) {
    if (isFirst) {
      yield UTF8.encode("$prefix\n");
      isFirst = false;
    }
    yield bytes;
  }
}

class BytesOutputSink implements Sink<List<int>> {
  final BytesBuilder bytesBuilder = new BytesBuilder();

  final Sink<List<int>> verboseSink;

  factory BytesOutputSink(bool isVerbose) {
    StreamController<List<int>> verboseController =
        new StreamController<List<int>>();
    Stream<List<int>> verboseStream = verboseController.stream;
    if (isVerbose) {
      verboseStream.transform(UTF8.decoder).transform(new LineSplitter())
          .listen(print);
    } else {
      verboseStream.listen(null);
    }
    return new BytesOutputSink.internal(verboseController);
  }

  BytesOutputSink.internal(this.verboseSink);

  void add(List<int> data) {
    verboseSink.add(data);
    bytesBuilder.add(data);
  }

  void writeln(String text) {
    add(UTF8.encode("$text\n"));
  }

  void close() {
    verboseSink.close();
  }
}

class FletchSessionHelper {
  final String executable;

  final int sessionId;

  final String session;

  final Map<String, String> environmentOverrides;

  final bool isVerbose;

  final BytesOutputSink stdout;

  final BytesOutputSink stderr;

  final BytesOutputSink vmStdout;

  final BytesOutputSink vmStderr;

  Process vmProcess;

  Future<int> vmExitCodeFuture;

  FletchSessionHelper(
      int sessionId,
      this.executable,
      this.environmentOverrides,
      this.isVerbose,
      bool superVerbose)
      : sessionId = sessionId,
        session = '$sessionId',
        stdout = new BytesOutputSink(superVerbose),
        stderr = new BytesOutputSink(superVerbose),
        vmStdout = new BytesOutputSink(superVerbose),
        vmStderr = new BytesOutputSink(superVerbose);

  List<int> get combinedStdout {
    stdout.close();
    vmStdout.close();
    BytesBuilder combined = new BytesBuilder()
        ..add(stdout.bytesBuilder.takeBytes())
        ..add(vmStdout.bytesBuilder.takeBytes());
    return combined.takeBytes();
  }

  List<int> get combinedStderr {
    stderr.close();
    vmStderr.close();
    BytesBuilder combined = new BytesBuilder()
        ..add(stderr.bytesBuilder.takeBytes())
        ..add(vmStderr.bytesBuilder.takeBytes());
    return combined.takeBytes();
  }

  Future<int> run(
      List<String> arguments,
      {bool checkExitCode: true}) async {
    Process process = await Process.start(
        "$executable", arguments, environment: environmentOverrides);
    String commandDescription = "$executable ${arguments.join(' ')}";
    if (isVerbose) {
      print("Running $commandDescription");
    }
    String commandDescriptionForLog = "\$ $commandDescription";
    stdout.writeln(commandDescriptionForLog);
    Future stdoutFuture = process.stdout.listen(stdout.add).asFuture();
    Future stderrFuture =
        addPrefixWhenNotEmpty(process.stderr, commandDescriptionForLog)
        .listen(stderr.add)
        .asFuture();
    await process.stdin.close();
    int exitCode = await process.exitCode;
    await stdoutFuture;
    await stderrFuture;

    stdout.add(UTF8.encode("\n => $exitCode\n"));
    if (checkExitCode && exitCode != 0) {
      throw new UnexpectedExitCode(exitCode, executable, arguments);
    }
    return exitCode;
  }

  Future<Null> runInSession(
      List<String> arguments,
      {bool checkExitCode: true}) {
    return run(
        []..addAll(arguments)..addAll(["in", "session", session]),
        checkExitCode: checkExitCode);
  }

  Future<String> spawnVm() async {
    FletchVm fletchVm = await FletchVm.start(
        "$executable-vm", environment: environmentOverrides);
    vmProcess = fletchVm.process;
    String commandDescription = "$executable-vm";
    if (isVerbose) {
      print("Running $commandDescription");
    }
    String commandDescriptionForLog = "\$ $commandDescription";
    vmStdout.writeln(commandDescriptionForLog);
    stdout.writeln('$commandDescriptionForLog &');

    Future stdoutFuture =
        fletchVm.stdoutLines.listen(vmStdout.writeln).asFuture();
    bool isFirstStderrLine = true;
    Future stderrFuture =
        fletchVm.stderrLines.listen(
            (String line) {
              if (isFirstStderrLine) {
                vmStdout.writeln(commandDescriptionForLog);
                isFirstStderrLine = false;
              }
              vmStdout.writeln(line);
            })
        .asFuture();

    vmExitCodeFuture = fletchVm.exitCode.then((int exitCode) async {
      await stdoutFuture;
      await stderrFuture;
      return exitCode;
    });

    return "${fletchVm.host}:${fletchVm.port}";
  }

  Future<bool> shutdownVm(int expectedExitCode) async {
    if (vmProcess == null) return;
    bool done = false;
    bool killed = false;
    Timer timer = new Timer(const Duration(seconds: 5), () {
      if (!done) {
        vmProcess.kill(ProcessSignal.SIGKILL);
        killed = true;
      }
    });
    int vmExitCode = await vmExitCodeFuture;
    done = true;
    timer.cancel();
    if (vmExitCode != expectedExitCode) {
      if (!killed || vmExitCode >= 0) {
        throw new UnexpectedExitCode(vmExitCode, "$executable-vm", <String>[]);
      }
    }
  }
}

Future<Null> main(List<String> arguments) async {
  String executable = arguments.first;
  String script = arguments[1];
  arguments = arguments.skip(2).toList();
  Map<String, String> environmentOverrides = <String, String>{};
  FletchSessionCommand command = new FletchSessionCommand(
      executable, script, arguments, environmentOverrides);
  FletchTestCommandOutput output =
      await command.run(0, true, superVerbose: true);
  print("Test outcome: ${output.decodeExitCode()}");
}
