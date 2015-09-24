// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.run_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    runDocumentation;

import '../driver/developer.dart' show
    compileAndAttachToLocalVmThen;

import '../driver/developer.dart' as developer;

const Verb runVerb =
    const Verb(
        run, runDocumentation, requiresSession: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> run(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new RunTask(sentence.targetUri));

  return null;
}

class RunTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  const RunTask(this.script);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return runTask(commandSender, SessionState.current, script);
  }
}

Future<int> runTask(
    CommandSender commandSender,
    SessionState state,
    Uri script) {
  return compileAndAttachToLocalVmThen(
      commandSender,
      state,
      script,
      () => developer.run(state));
}
