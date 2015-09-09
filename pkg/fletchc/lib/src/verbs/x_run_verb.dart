// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.x_run_verb;

import 'infrastructure.dart';

import 'dart:async' show
    Timer;

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

import '../driver/developer.dart' show
    printBacktraceHack;

import 'documentation.dart' show
    xRunDocumentation;

const Verb xRunVerb =
    const Verb(xRun, xRunDocumentation, requiresSession: true);

Future<int> xRun(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new XRunTask());

  return null;
}

class XRunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const XRunTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return xRunTask(commandSender, SessionState.current);
  }
}

Future<int> xRunTask(CommandSender commandSender, SessionState state) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (compilationResults.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  state.attachCommandSender(commandSender);
  state.session = null;
  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.runCommand(const commands_lib.ProcessSpawnForMain());

  await session.sendCommand(const commands_lib.ProcessRun());

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
    state.detachCommandSender();
  };

  return exitCode;
}
