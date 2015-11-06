// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.run_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    runDocumentation;

import '../driver/developer.dart' show
    compileAndAttachToVmThen;

import '../driver/developer.dart' as developer;

const Action runAction =
    const Action(
        run, runDocumentation, requiresSession: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> run(AnalyzedSentence sentence, VerbContext context) {
  return context.performTaskInWorker(
      new RunTask(sentence.targetUri, sentence.base));
}

class RunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  final Uri base;

  const RunTask(this.script, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return runTask(
        commandSender, commandIterator, SessionState.current, script, base);
  }
}

Future<int> runTask(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
    SessionState state,
    Uri script,
    Uri base) {
  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      () => developer.run(state));
}
