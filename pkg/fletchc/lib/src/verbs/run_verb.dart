// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.run_verb;

import 'dart:async' show
    Future,
    StreamIterator;

import 'dart:io' show
    Socket;

import 'verbs.dart' show
    Sentence,
    SharedTask,
    Verb,
    VerbContext;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

import '../../session.dart' show
    FletchVmSession;

import '../driver/session_manager.dart' show
    SessionState;

import '../../commands.dart' as commands_lib;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError,
    throwInternalError;

import '../../fletch_system.dart' show
    FletchDelta;

import 'documentation.dart' show
    runDocumentation;

const Verb runVerb =
    const Verb(run, runDocumentation, requiresSession: true);

Future<int> run(Sentence sentence, VerbContext context) async {
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
  FletchDelta compilationResult = SessionState.current.compilationResult;
  Socket socket = SessionState.current.vmSocket;
  if (socket == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (compilationResult == null) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  SessionState.current.vmSocket = null;
  FletchVmSession session = new FletchVmSession(socket);
  await session.runCommands(compilationResult.commands);

  await session.runCommand(const commands_lib.ProcessSpawnForMain());

  await session.sendCommand(const commands_lib.ProcessRun());

  // NOTE: The [ProcessRun] command normally results in a [ProcessTerminated]
  // command. But if the compiler emitted a compile time error, the fletch-vm
  // will just halt()/exit() and we therefore get no response.
  var command = await session.readNextCommand(force: false);
  if (command != null && command is! commands_lib.ProcessTerminated) {
    throwInternalError(
        "Expected program to finish complete with 'ProcessTerminated' "
        "but got '$command'");
  }

  await session.shutdown();

  return 0;
}
