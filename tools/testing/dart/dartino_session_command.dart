// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Provides a [Command] interface for interacting with a Dartino driver session.
///
/// Normally, this is used by test.dart, but is also has a [main] method that
/// makes it possible to run a test outside test.dart.
library test.dartino_session_command;

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

import '../../../pkg/dartino_compiler/lib/src/hub/exit_codes.dart' show
    COMPILER_EXITCODE_CONNECTION_ERROR,
    COMPILER_EXITCODE_CRASH,
    DART_VM_EXITCODE_COMPILE_TIME_ERROR,
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;

import '../../../pkg/dartino_compiler/lib/dartino_vm.dart' show
    DartinoVm;

const String settingsFileNameFlag = "test.dartino_settings_file_name";
const String settingsFileName =
    const String.fromEnvironment(settingsFileNameFlag);

/// Default timeout value (in seconds) used for running commands that are
/// assumed to complete fast.
// TODO(ahe): Lower this to 5 seconds.
const int defaultTimeout = 20;

final Queue<DartinoSessionMirror> sessions = new Queue<DartinoSessionMirror>();

int sessionCount = 0;

/// Return an available [DartinoSessionMirror] or construct a new.
DartinoSessionMirror getAvailableSession() {
  if (sessions.isEmpty) {
    return new DartinoSessionMirror(sessionCount++);
  } else {
    return sessions.removeFirst();
  }
}

void returnSession(DartinoSessionMirror session) {
  sessions.addLast(session);
}

String explainExitCode(int code) {
  String exit_message;
  if (code == null) {
    exit_message = "no exit code";
  } else if (code == 0) {
    exit_message = "(success exit code)";
  } else if (code > 0) {
    switch (code) {
      case COMPILER_EXITCODE_CONNECTION_ERROR:
        exit_message = "(connection error)";
        break;
      case COMPILER_EXITCODE_CRASH:
        exit_message = "(compiler crash)";
        break;
      case DART_VM_EXITCODE_COMPILE_TIME_ERROR:
        exit_message = "(compile-time error)";
        break;
      case DART_VM_EXITCODE_UNCAUGHT_EXCEPTION:
        exit_message = "(uncaught exception)";
        break;
      default:
        exit_message = "(error exit code)";
        break;
    }
  } else {
    exit_message = "(signal ${-code})";
    if (code == -15 || code == -9) {
      exit_message += " (killed by external signal - timeout?)";
    } else if (code == -7 || code == -11 || code == -4) {
      // SIGBUS, SIGSEGV, SIGILL
      exit_message += " (internal error)";
    } else if (code == -2) {
      exit_message += " (control-C)";
    } else {
      exit_message += " (see man 7 signal)";
    }
  }
  return exit_message;
}

class DartinoSessionCommand implements Command {
  final String executable;
  final String script;
  final List<String> arguments;
  final Map<String, String> environmentOverrides;
  final String snapshotFileName;
  final String settingsFileName;

  DartinoSessionCommand(
      this.executable,
      this.script,
      this.arguments,
      this.environmentOverrides,
      {this.snapshotFileName,
       this.settingsFileName: ".dartino-settings"});

  String get displayName => "dartino_session";

  int get maxNumRetries => 0;

  String get reproductionCommand {
    var dartVm = Uri.parse(executable).resolve('dart');
    String dartinoPath = Uri.parse(executable).resolve('dartino-vm').toString();
    String versionFlag = '-Ddartino.version=`$dartinoPath --version`';
    String settingsFileFlag = "-D$settingsFileNameFlag=$settingsFileName";

    return """



There are three ways to reproduce this error:

  1. Run the test exactly as in this test framework. This is the hardest to
     debug using gdb:

    ${Platform.executable} -c $settingsFileFlag \\
       $versionFlag \\
       tools/testing/dart/dartino_session_command.dart $executable \\
       ${arguments.join(' ')}


  2. Run the helper program `tests/dartino_compiler/run.dart` under `gdb` using
     `set follow-fork-mode child`. This can be confusing, but makes it
     easy to run a reproduction command in a loop:

    gdb -ex 'set follow-fork-mode child' -ex run --args \\
        $dartVm $settingsFileFlag \\
        $versionFlag \\
        -c tests/dartino_compiler/run.dart $script

  3. Run the `dartino-vm` in gdb and attach to it via the helper program. This
     is the easiest way to debug using both gdb and lldb. You need to start two
     processes, each in their own terminal window:

    gdb -ex run --args $executable-vm --port=54321

    $dartVm $settingsFileFlag \\
      $versionFlag \\
      -c -DattachToVm=54321 tests/dartino_compiler/run.dart $script


""";
  }

  Future<DartinoTestCommandOutput> run(
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

    DartinoSessionHelper dartino =
        new DartinoSessionHelper(
            getAvailableSession(), executable, environmentOverrides,
            verbose, superVerbose);

    dartino.sessionMirror.printLoggedCommands(dartino.stdout, executable);

    Stopwatch sw = new Stopwatch()..start();
    int exitCode;
    bool endedSession = false;
    try {
      Future vmTerminationFuture;
      try {
        await dartino.createSession(settingsFileName);

        // Now that the session is created, start a Dartino VM.
        String vmSocketAddress = await dartino.spawnVm();
        // Timeout of the VM is implemented by shutting down the Dartino VM
        // after [timeout] seconds. This ensures that compilation+runtime never
        // exceed [timeout] seconds (plus whatever time is spent in setting up
        // the session above).
        vmTerminationFuture = dartino.shutdownVm(timeout);
        await dartino.runInSession(["attach", "tcp_socket", vmSocketAddress]);
        if (snapshotFileName != null) {
          exitCode = await dartino.runInSession(
              ["export", script, 'to', 'file', snapshotFileName],
              checkExitCode: false, timeout: timeout);
        } else {
          exitCode = await dartino.runInSession(["compile", script],
              checkExitCode: false, timeout: timeout);
          dartino.stderr.writeln("Compilation took: ${sw.elapsed}");
          if (exitCode == 0) {
            exitCode = await dartino.runInSession(
                ["run", "--terminate-debugger"],
                checkExitCode: false, timeout: timeout);
          }
        }
      } finally {
        if (exitCode == COMPILER_EXITCODE_CRASH) {
          // If the compiler crashes, chances are that it didn't close the
          // connection to the Dartino VM. So we kill it.
          dartino.killVmProcess(ProcessSignal.SIGTERM);
        }
        int vmExitCode = await vmTerminationFuture;
        dartino.stdout.writeln("Dartino VM exitcode is $vmExitCode "
            "${explainExitCode(vmExitCode)}\n"
            "Exit code reported by ${dartino.executable} is $exitCode "
            "${explainExitCode(exitCode)}\n");
        if (exitCode == COMPILER_EXITCODE_CONNECTION_ERROR) {
          dartino.stderr.writeln("Connection error from compiler");
          exitCode = vmExitCode;
        } else if (exitCode != vmExitCode) {
          if (!dartino.killedVmProcess || vmExitCode == null ||
              vmExitCode >= 0) {
            throw new UnexpectedExitCode(
                vmExitCode, "${dartino.executable}-vm", <String>[]);
          }
        }
      }
    } on UnexpectedExitCode catch (error) {
      dartino.stderr.writeln("$error");
      exitCode = combineExitCodes(exitCode, error.exitCode);
      try {
        if (!endedSession) {
          // TODO(ahe): Only end if there's a crash.
          endedSession = true;
          await dartino.run(["x-end", "session", dartino.sessionName]);
        }
      } on UnexpectedExitCode catch (error) {
        dartino.stderr.writeln("$error");
        // TODO(ahe): Error ignored, long term we should be able to guarantee
        // that shutting down a session never leads to an error.
      }
    }

    if (exitCode == null) {
      exitCode = COMPILER_EXITCODE_CRASH;
      dartino.stdout.writeln(
          '**test.py** could not determine a good exitcode, using $exitCode.');
    }

    if (endedSession) {
      returnSession(new DartinoSessionMirror(dartino.sessionMirror.id));
    } else {
      returnSession(dartino.sessionMirror);
    }

    return new DartinoTestCommandOutput(
        this, exitCode, dartino.hasTimedOut,
        dartino.combinedStdout, dartino.combinedStderr, sw.elapsed, -1);
  }

  DartinoTestCommandOutput compilerFail(String message) {
    return new DartinoTestCommandOutput(
        this, DART_VM_EXITCODE_COMPILE_TIME_ERROR, false, <int>[],
        UTF8.encode(message), const Duration(seconds: 0), -1);
  }

  String toString() => reproductionCommand;

  set displayName(_) => throw "not supported";

  get commandLine => throw "not supported";
  set commandLine(_) => throw "not supported";

  get outputIsUpToDate => throw "not supported";
}

/// [compiler] is assumed to be coming from `dartino` in which case
/// [COMPILER_EXITCODE_CRASH], [DART_VM_EXITCODE_COMPILE_TIME_ERROR], and
/// [DART_VM_EXITCODE_UNCAUGHT_EXCEPTION] all represent a compiler crash.
///
/// [runtime] is assumed to be coming from `dartino-vm` in which case which case
/// [DART_VM_EXITCODE_COMPILE_TIME_ERROR], and
/// [DART_VM_EXITCODE_UNCAUGHT_EXCEPTION] is just the result of running a test
/// that has an error (not a crash).
int combineExitCodes(int compiler, int runtime) {
  if (compiler == null) return runtime;

  if (runtime == null) return compiler;

  switch (compiler) {
    case COMPILER_EXITCODE_CRASH:
    case DART_VM_EXITCODE_COMPILE_TIME_ERROR:
    case DART_VM_EXITCODE_UNCAUGHT_EXCEPTION:
      // If the compiler exits with any of those values above, it crashed. It
      // should never crash.
      return COMPILER_EXITCODE_CRASH;

    default:
      break;
  }

  if (compiler < 0) {
    // Normally, this would be a timeout. However, it can also signify that the
    // Dart VM crashed, with, for example, SIGABRT or SIGSEGV.
    return compiler;
  }

  return runtime;
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

class DartinoTestCommandOutput extends CommandOutputImpl with DecodeExitCode {
  DartinoTestCommandOutput(
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

class DartinoSessionHelper {
  final String executable;

  final DartinoSessionMirror sessionMirror;

  final String sessionName;

  final Map<String, String> environmentOverrides;

  final bool isVerbose;

  final BytesOutputSink stdout;

  final BytesOutputSink stderr;

  final BytesOutputSink vmStdout;

  final BytesOutputSink vmStderr;

  Process vmProcess;

  Future<int> vmExitCodeFuture;

  bool killedVmProcess = false;

  bool hasTimedOut = false;

  DartinoSessionHelper(
      DartinoSessionMirror sessionMirror,
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

  /// Run [executable] with arguments and wait for it to exit.  This method
  /// uses [exitCodeWithTimeout] to ensure the process exits within [timeout]
  /// seconds.
  ///
  /// If the process times out, UnexpectedExitCode is thrown.
  ///
  /// If [checkExitCode] is true (the default), UnexpectedExitCode is thrown
  /// unless the process' exit code is 0.
  Future<int> run(
      List<String> arguments,
      {bool checkExitCode: true,
       int timeout: defaultTimeout}) async {
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

    // Can't reuse [hasTimedOut] as we don't want to throw when calling 'x-end'
    // in the finally block above.
    bool thisCommandTimedout = false;

    int exitCode = await exitCodeWithTimeout(process, timeout, () {
      stdout.writeln(
          "\n=> Reached command timeout (sent SIGTERM to dartino-vm)");
      thisCommandTimedout = true;
      hasTimedOut = true;
      if (vmProcess != null) {
        killedVmProcess = vmProcess.kill(ProcessSignal.SIGTERM);
      }
    });
    await stdoutFuture;
    await stderrFuture;

    stdout.writeln("\n => $exitCode ${explainExitCode(exitCode)}\n");
    if (checkExitCode && (thisCommandTimedout || exitCode != 0)) {
      throw new UnexpectedExitCode(exitCode, executable, arguments);
    }
    return exitCode;
  }

  /// Same as [run], except that the arguments "in session $sessionName" are
  /// implied.
  Future<int> runInSession(
      List<String> arguments,
      {bool checkExitCode: true,
       int timeout: defaultTimeout}) {
    return run(
        []..addAll(arguments)..addAll(["in", "session", sessionName]),
        checkExitCode: checkExitCode, timeout: timeout);
  }

  Future<int> createSession(String settingsFileName) async {
    if (sessionMirror.isCreated) {
      return 0;
    } else {
      sessionMirror.isCreated = true;
      return await run(
          ["create", "session", sessionName, "with", settingsFileName]);
    }
  }

  Future<String> spawnVm() async {
    DartinoVm dartinoVm = await DartinoVm.start(
        "$executable-vm", environment: environmentOverrides);
    vmProcess = dartinoVm.process;
    String commandDescription = "$executable-vm";
    if (isVerbose) {
      print("Running $commandDescription");
    }
    String commandDescriptionForLog = "\$ $commandDescription";
    vmStdout.writeln(commandDescriptionForLog);
    stdout.writeln('$commandDescriptionForLog &');

    Future stdoutFuture =
        dartinoVm.stdoutLines.listen(vmStdout.writeln).asFuture();
    bool isFirstStderrLine = true;
    Future stderrFuture =
        dartinoVm.stderrLines.listen(
            (String line) {
              if (isFirstStderrLine) {
                vmStdout.writeln(commandDescriptionForLog);
                isFirstStderrLine = false;
              }
              vmStdout.writeln(line);
            })
        .asFuture();

    vmExitCodeFuture = dartinoVm.exitCode.then((int exitCode) async {
      if (isVerbose) print("Exiting Dartino VM with exit code $exitCode.");
      await stdoutFuture;
      if (isVerbose) print("Stdout of Dartino VM process closed.");
      await stderrFuture;
      if (isVerbose) print("Stderr of Dartino VM process closed.");
      return exitCode;
    });

    return "${dartinoVm.host}:${dartinoVm.port}";
  }

  /// Returns a future that completes when the dartino VM exits using
  /// [exitCodeWithTimeout] to ensure termination within [timeout] seconds.
  Future<int> shutdownVm(int timeout) async {
    await exitCodeWithTimeout(vmProcess, timeout, () {
      stdout.writeln(
          "\n**dartino-vm** Reached total timeout (sent SIGTERM to dartino-vm)");
      killedVmProcess = true;
      hasTimedOut = true;
    });
    return vmExitCodeFuture;
  }

  void killVmProcess(ProcessSignal signal) {
    if (vmProcess == null) return;
    killedVmProcess = vmProcess.kill(ProcessSignal.SIGTERM);
  }
}

/// Helper method for implementing timing out while waiting for [process] to
/// exit. [timeout] is in seconds. If the process times out, it will be killed
/// using SIGTERM and onTimeout will be called.
///
/// After SIGTERM, the process has 5 seconds to exit or it will be killed with
/// SIGKILL.
///
/// Note: We treat SIGKILL as a crash, not a timeout. The process is supposed
/// to exit quickly and gracefully after receiving SIGTERM. See
/// [DecodeExitCode] in `decode_exit_code.dart`.
Future<int> exitCodeWithTimeout(
    Process process,
    int timeout,
    void onTimeout()) async {
  if (process == null) return 0;

  bool done = false;
  Timer timer;

  void secondTimeout() {
    if (done) return;
    process.kill(ProcessSignal.SIGKILL);
  }

  void firstTimeout() {
    if (done) return;
    if (process.kill(ProcessSignal.SIGTERM)) {
      timer = new Timer(const Duration(seconds: 5), secondTimeout);
      onTimeout();
    }
  }

  timer = new Timer(new Duration(seconds: timeout), firstTimeout);

  int exitCode = await process.exitCode;
  done = true;
  timer.cancel();
  return exitCode;
}

/// Represents a session in the persistent Dartino client process.
class DartinoSessionMirror {
  static const int RINGBUFFER_SIZE = 15;

  final int id;

  final Queue<List<String>> internalLoggedCommands = new Queue<List<String>>();

  bool isCreated = false;

  DartinoSessionMirror(this.id);

  void logCommand(List<String> command) {
    internalLoggedCommands.add(command);
    if (internalLoggedCommands.length >= RINGBUFFER_SIZE) {
      internalLoggedCommands.removeFirst();
    }
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
  DartinoSessionCommand command = new DartinoSessionCommand(
      executable, script, arguments, environmentOverrides,
      settingsFileName: settingsFileName);
  DartinoTestCommandOutput output =
      await command.run(0, true, superVerbose: true);
  print("Test outcome: ${output.decodeExitCode()}");
}
