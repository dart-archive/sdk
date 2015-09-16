// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.developer;

import 'dart:async' show
    Future,
    Timer;

import 'dart:io' show
    Socket,
    SocketException;

import '../../commands.dart' show
    CommandCode,
    ProcessBacktrace,
    ProcessBacktraceRequest,
    ProcessRun,
    ProcessSpawnForMain,
    SessionEnd;

import 'session_manager.dart' show
    FletchVm,
    SessionState;

import 'driver_commands.dart' show
    handleSocketErrors;

import '../../commands.dart' show
    Debugging;

import '../verbs/infrastructure.dart' show
    Command,
    CommandSender,
    DiagnosticKind,
    FletchCompiler,
    FletchDelta,
    IncrementalCompiler,
    IsolateController,
    IsolatePool,
    Session,
    SharedTask,
    StreamIterator,
    throwFatalError;

import '../../incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import 'exit_codes.dart' as exit_codes;

import '../../fletch_system.dart' show
    FletchFunction,
    FletchSystem;

import '../../bytecodes.dart' show
    Bytecode,
    MethodEnd;

import '../diagnostic.dart' show
    throwInternalError;

Future<Null> attachToLocalVm(Uri programName, SessionState state) async {
  String fletchVmPath = programName.resolve("fletch-vm").toFilePath();
  state.fletchVm = await FletchVm.start(fletchVmPath);
  await attachToVm(state.fletchVm.host, state.fletchVm.port, state);
  await state.session.disableVMStandardOutput();
}

Future<Null> attachToVm(
    String host,
    int port,
    SessionState sessionState) async {
  Socket socket = await Socket.connect(host, port).catchError(
      (SocketException error) {
        String message = error.message;
        if (error.osError != null) {
          message = error.osError.message;
        }
        throwFatalError(
            DiagnosticKind.socketConnectError,
            address: '$host:$port', message: message);
      }, test: (e) => e is SocketException);
  String remotePort = "?";
  try {
    remotePort = "${socket.remotePort}";
  } catch (_) {
    // Ignored, socket.remotePort may fail if the socket was closed on the
    // other side.
  }

  Session session =
      new Session(handleSocketErrors(socket, "vmSocket"),
                  sessionState.compiler,
                  sessionState.stdoutSink,
                  sessionState.stderrSink,
                  null);

  // Enable debugging as a form of handshake.
  await session.runCommand(const Debugging());

  print("Connected to Fletch VM on TCP socket ${socket.port} -> $remotePort");

  sessionState.session = session;
}

Future<int> compile(Uri script, SessionState state) async {
  Uri firstScript = state.script;
  List<FletchDelta> previousResults = state.compilationResults;
  IncrementalCompiler compiler = state.compiler;

  FletchDelta newResult;
  try {
    if (previousResults.isEmpty) {
      state.script = script;
      await compiler.compile(script);
      newResult = compiler.computeInitialDelta();
    } else {
      try {
        print("Compiling difference from $firstScript to $script");
        newResult = await compiler.compileUpdates(
            previousResults.last.system, <Uri, Uri>{firstScript: script},
            logTime: print, logVerbose: print);
      } on IncrementalCompilationFailed catch (error) {
        print(error);
        print("Attempting full compile...");
        state.resetCompiler();
        state.script = script;
        await compiler.compile(script);
        newResult = compiler.computeInitialDelta();
      }
    }
  } catch (error, stackTrace) {
    // Don't let a compiler crash bring down the session.
    print(error);
    if (stackTrace != null) {
      print(stackTrace);
    }
    return exit_codes.COMPILER_EXITCODE_CRASH;
  }
  state.addCompilationResult(newResult);

  print("Compiled '$script' to ${newResult.commands.length} commands\n\n\n");

  return 0;
}

SessionState createSessionState(String name) {
  // TODO(ahe): Allow user to specify dart2js options.
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compilerHelper = new FletchCompiler(
      options: compilerOptions,
      // TODO(ahe): packageRoot should be a user provided option.
      packageRoot: 'package/');

  return new SessionState(
      name, compilerHelper, compilerHelper.newIncrementalCompiler());
}

Future<int> run(SessionState state) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  state.session = null;

  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.runCommand(const ProcessSpawnForMain());

  await session.sendCommand(const ProcessRun());

  var command = await session.readNextCommand(force: false);
  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  if (command == null) {
    await session.kill();
    await session.shutdown();
    throwInternalError("No command received from Fletch VM");
  }
  try {
    switch (command.code) {
      case CommandCode.UncaughtException:
        print("Uncaught error");
        exitCode = exit_codes.DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        await printBacktraceHack(session, compilationResults.last.system);
        // TODO(ahe): Need to continue to unwind stack.
        break;

      case CommandCode.ProcessCompileTimeError:
        print("Compile-time error");
        exitCode = exit_codes.DART_VM_EXITCODE_COMPILE_TIME_ERROR;
        await printBacktraceHack(session, compilationResults.last.system);
        // TODO(ahe): Continue to unwind stack?
        break;

      case CommandCode.ProcessTerminated:
        exitCode = 0;
        break;

      default:
        throwInternalError("Unexpected result from Fletch VM: '$command'");
        break;
    }
  } finally {
    // TODO(ahe): Do not shut down the session.
    await session.runCommand(const SessionEnd());
    bool done = false;
    Timer timer = new Timer(const Duration(seconds: 5), () {
      if (!done) {
        print("Timed out waiting for Fletch VM to shutdown; killing session");
        session.kill();
      }
    });
    await session.shutdown();
    done = true;
    timer.cancel();
  };

  return exitCode;
}

/// Prints a low-level stack trace like this:
///
/// ```
/// @baz+6
///  0: load const @0
/// *5: throw
///  6: return 1 0
///  9: method end 9
/// @bar+5
/// *0: invoke static @0
///  5: return 1 0
///  8: method end 8
/// ...
/// ```
///
/// A line starting with `@` shows the name of the function followed by `+` and
/// a bytecode index.
///
/// The following lines (until the next line starting with `@`) shows the
/// bytecodes of the method where the current bytecode is marked with `*` (an
/// asterisk).
// TODO(ahe): Clearly this should use the class [Session], but need to
// coordinate with ager first.
Future<Null> printBacktraceHack(Session session, FletchSystem system) async {
  ProcessBacktrace backtrace =
      await session.runCommand(const ProcessBacktraceRequest());
  if (backtrace == null) {
    await session.kill();
    await session.shutdown();
    throwInternalError("No command received from Fletch VM");
  }
  bool isBadBacktrace = false;
  for (int i = backtrace.frames - 1; i >= 0; i--) {
    int id = backtrace.functionIds[i];
    int stoppedPc = backtrace.bytecodeIndices[i];
    FletchFunction function = system.lookupFunctionById(id);
    if (function == null) {
      print("#$id+$stoppedPc // COMPILER BUG!!!");
      isBadBacktrace = true;
      continue;
    }
    if (function.element != null &&
        function.element.implementation.library.isInternalLibrary) {
      // TODO(ahe): This hides implementation details, which should be a
      // user-controlled option.
      continue;
    }
    print("@${function.name}+$stoppedPc");

    // The last bytecode is always a MethodEnd. It always contains its own
    // index (at uint32Argument0). This is used by the Fletch VM when walking
    // stacks (for example, during garbage collection). Here we use it to
    // compute the maximum bytecode offset we need to print.
    MethodEnd end = function.bytecodes.last;
    int maxPadding = "${end.uint32Argument0}".length;
    String padding = " " * maxPadding;
    int pc = 0;
    for (Bytecode bytecode in function.bytecodes) {
      String prefix = "$padding$pc";
      prefix = prefix.substring(prefix.length - maxPadding);
      if (stoppedPc == pc + bytecode.size) {
        prefix = "*$prefix";
      } else {
        prefix = " $prefix";
      }
      print("$prefix: $bytecode");
      pc += bytecode.size;
    }
  }
  if (isBadBacktrace) {
    throwInternalError("COMPILER BUG in above stacktrace");
  }
}

Future<int> export(SessionState state, Uri snapshot) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  state.session = null;

  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.writeSnapshot(snapshot.toFilePath());
  await session.shutdown();

  return 0;
}

Future<int> compileAndAttachToLocalVmThen(
    CommandSender commandSender,
    SessionState state,
    Uri programName,
    Uri script,
    Future<int> action()) async {
  bool startedVm = false;
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  if (compilationResults.isEmpty || script != null) {
    if (script == null) {
      throwFatalError(DiagnosticKind.noFileTarget);
    }
    int exitCode = await compile(script, state);
    if (exitCode != 0) return exitCode;
    compilationResults = state.compilationResults;
    assert(compilationResults != null);
  }
  if (session == null) {
    startedVm = true;
    await attachToLocalVm(programName, state);
    state.fletchVm.stdoutLines.listen((String line) {
      commandSender.sendStdout("$line\n");
    });
    state.fletchVm.stderrLines.listen((String line) {
      commandSender.sendStderr("$line\n");
    });
    session = state.session;
    assert(session != null);
  }

  state.attachCommandSender(commandSender);

  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
  try {
    exitCode = await action();
  } catch (error, trace) {
    print(error);
    if (trace != null) {
      print(trace);
    }
  } finally {
    if (startedVm) {
      exitCode = await state.fletchVm.exitCode;
    }
    state.detachCommandSender();
  }
  return exitCode;
}

Future<IsolateController> allocateWorker(IsolatePool pool) async {
  IsolateController worker =
      new IsolateController(await pool.getIsolate(exitOnError: false));
  await worker.beginSession();
  return worker;
}

SharedTask combineTasks(SharedTask task1, SharedTask task2) {
  if (task1 == null) return task2;
  if (task2 == null) return task1;
  return new CombinedTask(task1, task2);
}

class CombinedTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final SharedTask task1;

  final SharedTask task2;

  const CombinedTask(this.task1, this.task2);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return invokeCombinedTasks(commandSender, commandIterator, task1, task2);
  }
}

Future<int> invokeCombinedTasks(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
    SharedTask task1,
    SharedTask task2) async {
  await task1(commandSender, commandIterator);
  return task2(commandSender, commandIterator);
}
