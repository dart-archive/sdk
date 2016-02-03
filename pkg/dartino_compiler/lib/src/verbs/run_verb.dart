// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.run_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    runDocumentation;

import '../worker/developer.dart' show
    compileAndAttachToVmThen;

import '../worker/developer.dart' as developer;

const Action runAction =
    const Action(
        run, runDocumentation, requiresSession: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> run(AnalyzedSentence sentence, VerbContext context) {
  bool terminateDebugger = sentence.options.terminateDebugger;
  List<String> testDebuggerCommands = sentence.options.testDebuggerCommands;
  return context.performTaskInWorker(
      new RunTask(
          sentence.targetUri, sentence.base, terminateDebugger,
          testDebuggerCommands));
}

class RunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  final Uri base;

  /// When true, terminate the debugger session before returning from
  /// [runTask]. Otherwise, the debugger session will be available after
  /// [runTask] completes.
  final bool terminateDebugger;

  final List<String> testDebuggerCommands;

  const RunTask(
      this.script,
      this.base,
      this.terminateDebugger,
      this.testDebuggerCommands);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return runTask(
        commandSender, commandIterator, SessionState.current, script, base,
        terminateDebugger, testDebuggerCommands);
  }
}

Future<int> runTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri base,
    bool terminateDebugger,
    List<String> testDebuggerCommands) {
  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      terminateDebugger,
      () => developer.run(
          state, testDebuggerCommands: testDebuggerCommands,
          terminateDebugger: terminateDebugger));
}
