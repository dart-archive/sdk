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
    COMPILER_EXITCODE_CONNECTION_ERROR,
    COMPILER_EXITCODE_CRASH,
    DART_VM_EXITCODE_COMPILE_TIME_ERROR,
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;

import '../../../pkg/fletchc/lib/fletch_vm.dart' show
    FletchVm;

const String settingsFileNameFlag = "test.fletch_settings_file_name";
const String settingsFileName =
    const String.fromEnvironment(settingsFileNameFlag);

/// Default timeout value (in seconds) used for running commands that are
/// assumed to complete fast.
// TODO(ahe): Lower this to 5 seconds.
const int defaultTimeout = 20;

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
  final String snapshotFileName;
  final String settingsFileName;

  FletchSessionCommand(
      this.executable,
      this.script,
      this.arguments,
      this.environmentOverrides,
      {this.snapshotFileName,
       this.settingsFileName: ".fletch-settings"});

  String get displayName => "fletch_session";

  int get maxNumRetries => 0;

  String get reproductionCommand {
    var dartVm = Uri.parse(executable).resolve('dart');
    String fletchPath = Uri.parse(executable).resolve('fletch-vm').toString();
    String versionFlag = '-Dfletch.version=`$fletchPath --version`';
    String settingsFileFlag = "-D$settingsFileNameFlag=$settingsFileName";

    return """



There are three ways to reproduce this error:

  1. Run the test exactly as in this test framework. This is the hardest to
     debug using gdb:

    ${Platform.executable} -c $settingsFileFlag \\
       $versionFlag \\
       tools/testing/dart/fletch_session_command.dart $executable \\
       ${arguments.join(' ')}


  2. Run the helper program `tests/fletchc/run.dart` under `gdb` using
     `set follow-fork-mode child`. This can be confusing, but makes it
     easy to run a reproduction command in a loop:

    gdb -ex 'set follow-fork-mode child' -ex run --args \\
        $dartVm $settingsFileFlag \\
        $versionFlag \\
        -c tests/fletchc/run.dart $script

  3. Run the `fletch-vm` in gdb and attach to it via the helper program. This
     is the easiest way to debug using both gdb and lldb. You need to start two
     processes, each in their own terminal window:

    gdb -ex run --args $executable-vm --port=54321

    $dartVm $settingsFileFlag \\
      $versionFlag \\
      -c -DattachToVm=54321 tests/fletchc/run.dart $script


""";
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
    int exitCode;
    bool endedSession = false;
    try {
      Future vmTerminationFuture;
      try {
        await fletch.createSession(settingsFileName);
        await fletch.runInSession(["show", "log"]);

        // Now that the session is created, start a Fletch VM.
        String vmSocketAddress = await fletch.spawnVm();
        // Timeout of the VM is implemented by shutting down the Fletch VM
        // after [timeout] seconds. This ensures that compilation+runtime never
        // exceed [timeout] seconds (plus whatever time is spent in setting up
        // the session above).
        vmTerminationFuture = fletch.shutdownVm(timeout);
        await fletch.runInSession(["attach", "tcp_socket", vmSocketAddress]);
        if (snapshotFileName != null) {
          exitCode = await fletch.runInSession(
              ["export", script, 'to', 'file', snapshotFileName],
              checkExitCode: false, timeout: timeout);
        } else {
          exitCode = await fletch.runInSession(
              ["run", "--terminate-debugger", script],
              checkExitCode: false, timeout: timeout);
        }
      } finally {
        if (exitCode == COMPILER_EXITCODE_CRASH) {
          // If the compiler crashes, chances are that it didn't close the
          // connection to the Fletch VM. So we kill it.
          fletch.killVmProcess(ProcessSignal.SIGTERM);
        }
        int vmExitCode = await vmTerminationFuture;
        fletch.stderr.writeln("Fletch VM exitcode is $vmExitCode");
        if (exitCode == COMPILER_EXITCODE_CONNECTION_ERROR) {
          exitCode = vmExitCode;
        } else if (exitCode != vmExitCode) {
          if (!fletch.killedVmProcess || vmExitCode >= 0) {
            throw new UnexpectedExitCode(
                vmExitCode, "${fletch.executable}-vm", <String>[]);
          }
        }
      }
    } on UnexpectedExitCode catch (error) {
      fletch.stderr.writeln("$error");
      exitCode = combineExitCodes(exitCode, error.exitCode);
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

    if (exitCode == null) {
      exitCode = COMPILER_EXITCODE_CRASH;
    }

    if (endedSession) {
      returnSession(new FletchSessionMirror(fletch.sessionMirror.id));
    } else {
      returnSession(fletch.sessionMirror);
    }

    return new FletchTestCommandOutput(
        this, exitCode, fletch.hasTimedOut,
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

/// [compiler] is assumed to be coming from `fletch` in which case
/// [COMPILER_EXITCODE_CRASH], [DART_VM_EXITCODE_COMPILE_TIME_ERROR], and
/// [DART_VM_EXITCODE_UNCAUGHT_EXCEPTION] all represent a compiler crash.
///
/// [runtime] is assumed to be coming from `fletch-vm` in which case which case
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

  bool killedVmProcess = false;

  bool hasTimedOut = false;

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
      print("Timed out: $commandDescription");
      thisCommandTimedout = true;
      hasTimedOut = true;
      if (vmProcess != null) {
        killedVmProcess = vmProcess.kill(ProcessSignal.SIGTERM);
      }
    });
    await stdoutFuture;
    await stderrFuture;

    stdout.add(UTF8.encode("\n => $exitCode\n"));
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
      if (isVerbose) print("Exiting Fletch VM with exit code $exitCode.");
      await stdoutFuture;
      if (isVerbose) print("Stdout of Fletch VM process closed.");
      await stderrFuture;
      if (isVerbose) print("Stderr of Fletch VM process closed.");
      return exitCode;
    });

    return "${fletchVm.host}:${fletchVm.port}";
  }

  /// Returns a future that completes when the fletch VM exits using
  /// [exitCodeWithTimeout] to ensure termination within [timeout] seconds.
  Future<int> shutdownVm(int timeout) async {
    await exitCodeWithTimeout(vmProcess, timeout, () {
      print("Timed out: $executable-vm");
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

/// Represents a session in the persistent Fletch driver process.
class FletchSessionMirror {
  final int id;

  final List<List<String>> internalLoggedCommands = <List<String>>[];

  bool isCreated = false;

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
  FletchSessionCommand command = new FletchSessionCommand(
      executable, script, arguments, environmentOverrides,
      settingsFileName: settingsFileName);
  FletchTestCommandOutput output =
      await command.run(0, true, superVerbose: true);
  print("Test outcome: ${output.decodeExitCode()}");
}
