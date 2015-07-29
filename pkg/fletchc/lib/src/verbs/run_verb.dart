// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.run_verb;

import 'infrastructure.dart';

import 'dart:async' show
    Timer;

import 'dart:collection' show
    Queue;

import '../../session.dart' show
    Session; // Only for documentation.

import '../../commands.dart' as commands_lib;

import '../../commands.dart' show
    CommandCode;

import '../../fletch_system.dart' show
    FletchFunction,
    FletchSystem;

import '../driver/exit_codes.dart' as exit_codes;

import '../../bytecodes.dart' show
    Bytecode,
    MethodEnd;

import '../diagnostic.dart' show
    throwInternalError;

import 'documentation.dart' show
    runDocumentation;

const Verb runVerb =
    const Verb(run, runDocumentation, requiresSession: true);

Future<int> run(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new RunTask());

  return null;
}

class RunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const RunTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return runTask(commandSender, commandIterator);
  }
}

Future<int> runTask(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  List<FletchDelta> compilationResults =
      SessionState.current.compilationResults;
  FletchVmSession session = SessionState.current.vmSession;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (compilationResults.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  SessionState.current.vmSession = null;
  for (FletchDelta delta in compilationResults) {
    await session.runCommands(delta.commands);
  }

  await session.runCommand(const commands_lib.ProcessSpawnForMain());

  await session.sendCommand(const commands_lib.ProcessRun());

  var command = await session.readNextCommand(force: false);
  int exitCode = exit_codes.COMPILER_EXITCODE_CRASH;
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
    await session.runCommand(const commands_lib.SessionEnd());
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
Future<Null> printBacktraceHack(
    FletchVmSession session,
    FletchSystem system) async {
  commands_lib.ProcessBacktrace backtrace =
      await session.runCommand(const commands_lib.ProcessBacktraceRequest());
  for (int i = backtrace.frames - 1; i >= 0; i--) {
    FletchFunction function =
        system.lookupFunctionById(backtrace.functionIds[i]);
    if (function.element != null &&
        function.element.implementation.library.isInternalLibrary) {
      // TODO(ahe): This hides implementation details, which should be a
      // user-controlled option.
      continue;
    }
    int stoppedPc = backtrace.bytecodeIndices[i];
    print("@${function.name}+${stoppedPc}");

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
}
