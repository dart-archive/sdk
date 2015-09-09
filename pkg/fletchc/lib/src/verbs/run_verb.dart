// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.run_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    runDocumentation;

import '../driver/developer.dart' show
    attachToLocalVm,
    compile;

import '../driver/developer.dart' as developer;

const Verb runVerb =
    const Verb(
        run, runDocumentation, requiresSession: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> run(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(
      new RunTask(sentence.programName, sentence.targetName));

  return null;
}

class RunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String programName;

  final String script;

  const RunTask(this.programName, this.script);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return runTask(commandSender, SessionState.current, programName, script);
  }
}

Future<int> runTask(
    CommandSender commandSender,
    SessionState state,
    String programName,
    String script) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  if (compilationResults.isEmpty || script != null) {
    int exitCode = await compile(script, state);
    if (exitCode != 0) return exitCode;
    compilationResults = state.compilationResults;
    assert(compilationResults != null);
  }
  if (session == null) {
    await attachToLocalVm(programName, state);
    session = state.session;
    assert(session != null);
  }

  state.attachCommandSender(commandSender);

  try {
    return await developer.run(state);
  } finally {
    state.detachCommandSender();
  }
}
