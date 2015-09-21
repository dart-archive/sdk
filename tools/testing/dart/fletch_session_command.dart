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
    CommandOutputImpl;

import 'decode_exit_code.dart' show
    DecodeExitCode;

import '../../../pkg/fletchc/lib/src/driver/exit_codes.dart' show
    COMPILER_EXITCODE_CRASH,
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

import '../../../pkg/fletchc/lib/fletch_vm.dart' show
    FletchVm;

const String isIncrementalCompilationEnabledFlag =
    "test.fletch_session_command.is_incremental_enabled";

final Queue<FletchSessionMirror> sessions = new Queue<FletchSessionMirror>();

int sessionCount = 0;

/// Return an available [FletchSessionMirror] or construct a new.
FletchSessionMirror getAvailableSession() {
  if (sessions.isEmpty) {
    return new FletchSessionMirror(sessionCount++);
  } else {
    return sessions.removeFirst();
  }
}

void returnSession(FletchSessionMirror session) {
  sessions.addLast(session);
}

class FletchSessionCommand implements Command {
  final String executable;
  final String script;
  final List<String> arguments;
  final Map<String, String> environmentOverrides;
  final bool isIncrementalCompilationEnabled;

  FletchSessionCommand(
      this.executable,
      this.script,
      this.arguments,
      this.environmentOverrides,
      this.isIncrementalCompilationEnabled);

  String get displayName => "fletch_session";

  int get maxNumRetries => 0;

  String get reproductionCommand {
    var dartVm = Uri.parse(executable).resolve('dart');
    return "${Platform.executable} -c "
        "-D$isIncrementalCompilationEnabledFlag="
        "$isIncrementalCompilationEnabled "
        "tools/testing/dart/fletch_session_command.dart "
        "$executable ${arguments.join(' ')}\n"
        "OR\n"
        "gdb -ex run --args "
        "$dartVm -c -ppackage/ tests/fletchc/run.dart $script";
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
            getAvailableSession(), executable, environmentOverrides,
            verbose, superVerbose);

    fletch.sessionMirror.printLoggedCommands(fletch.stdout, executable);

    Stopwatch sw = new Stopwatch()..start();
    int exitCode = COMPILER_EXITCODE_CRASH;
    bool endedSession = false;
    try {
      if (!fletch.sessionMirror.isCreatedInPersistentProcess) {
        int createSessionStatus = await fletch.run(
            ["create", "session", fletch.sessionName], checkExitCode: false);
        if (createSessionStatus != 0 && createSessionStatus != 1) {
          throw new UnexpectedExitCode(
              createSessionStatus, executable,
              ["create", "session", fletch.sessionName]);
        }
        fletch.sessionMirror.isCreatedInPersistentProcess = true;
      }
      try {
        await fletch.runInSession(["compile", script]);
        String vmSocketAddress = await fletch.spawnVm();
        await fletch.runInSession(["attach", "tcp_socket", vmSocketAddress]);
        exitCode = await fletch.runInSession(["x-run"], checkExitCode: false);
      } finally {
        await fletch.shutdownVm(exitCode);
      }
      if (!isIncrementalCompilationEnabled) {
        endedSession = true;
        await fletch.run(["x-end", "session", fletch.sessionName]);
      }
    } on UnexpectedExitCode catch (error) {
      fletch.stderr.writeln("$error");
      exitCode = error.exitCode;
      try {
        if (!endedSession) {
          // TODO(ahe): Only end if there's a crash.
          endedSession = true;
          await fletch.run(["x-end", "session", fletch.sessionName]);
        }
      } on UnexpectedExitCode catch (error) {
        fletch.stderr.writeln("$error");
        // TODO(ahe): Error ignored, long term we should be able to guarantee
        // that shutting down a session never leads to an error.
      }
    }

    if (endedSession) {
      returnSession(new FletchSessionMirror(fletch.sessionMirror.id));
    } else {
      returnSession(fletch.sessionMirror);
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

class FletchTestCommandOutput extends CommandOutputImpl with DecodeExitCode {
  FletchTestCommandOutput(
      Command command,
      int exitCode,
      bool timedOut,
      List<int> stdout,
      List<int> stderr,
      Duration time,
      int pid)
      : super(command, exitCode, timedOut, stdout, stderr, time, false, pid);
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
    writeText("$text\n");
  }

  void writeText(String text) {
    add(UTF8.encode(text));
  }

  void close() {
    verboseSink.close();
  }
}

class FletchSessionHelper {
  final String executable;

  final FletchSessionMirror sessionMirror;

  final String sessionName;

  final Map<String, String> environmentOverrides;

  final bool isVerbose;

  final BytesOutputSink stdout;

  final BytesOutputSink stderr;

  final BytesOutputSink vmStdout;

  final BytesOutputSink vmStderr;

  Process vmProcess;

  Future<int> vmExitCodeFuture;

  FletchSessionHelper(
      FletchSessionMirror sessionMirror,
      this.executable,
      this.environmentOverrides,
      this.isVerbose,
      bool superVerbose)
      : sessionMirror = sessionMirror,
        sessionName = sessionMirror.makeSessionName(),
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
    sessionMirror.logCommand(arguments);
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
        []..addAll(arguments)..addAll(["in", "session", sessionName]),
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

/// Represents a session in the persistent Fletch driver process.
class FletchSessionMirror {
  final int id;

  final List<List<String>> internalLoggedCommands = <List<String>>[];

  /// When this object is created, its corresponding session in the fletch
  /// driver process hasn't been created yet.
  bool isCreatedInPersistentProcess = false;

  FletchSessionMirror(this.id);

  void logCommand(List<String> command) {
    internalLoggedCommands.add(command);
  }

  void printLoggedCommands(BytesOutputSink sink, String executable) {
    sink.writeln("Previous commands in this session:");
    for (List<String> command in internalLoggedCommands) {
      sink.writeText(executable);
      for (String argument in command) {
        sink.writeText(" ");
        sink.writeText(argument);
      }
      sink.writeln("");
    }
    sink.writeln("");
  }

  String makeSessionName() => '$id';
}

Future<Null> main(List<String> arguments) async {
  // Setting [sessionCount] to the current time in milliseconds ensures that it
  // is highly unlikely that reproduction commands conflicts with an existing
  // session in a persistent process that wasn't killed.
  sessionCount = new DateTime.now().millisecondsSinceEpoch;
  String executable = arguments.first;
  String script = arguments[1];
  arguments = arguments.skip(2).toList();
  Map<String, String> environmentOverrides = <String, String>{};
  bool isIncrementalCompilationEnabled = const bool.fromEnvironment(
      isIncrementalCompilationEnabledFlag);
  FletchSessionCommand command = new FletchSessionCommand(
      executable, script, arguments, environmentOverrides,
      isIncrementalCompilationEnabled);
  FletchTestCommandOutput output =
      await command.run(0, true, superVerbose: true);
  print("Test outcome: ${output.decodeExitCode()}");
}
