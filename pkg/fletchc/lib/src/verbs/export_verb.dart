// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.export_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    exportDocumentation;

import '../driver/developer.dart' show
    compileAndAttachToVmThen;

import '../driver/developer.dart' as developer;

const Action exportAction =
    const Action(
        export, exportDocumentation, requiresSession: true,
        requiresToUri: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> export(AnalyzedSentence sentence, VerbContext context) {
  return context.performTaskInWorker(
      new ExportTask(sentence.targetUri, sentence.toTargetUri));
}

class ExportTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  final Uri snapshot;

  const ExportTask(this.script, this.snapshot);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return exportTask(
        commandSender, commandIterator, SessionState.current, script, snapshot);
  }
}

Future<int> exportTask(
    CommandSender commandSender,
    StreamIterator<Command> commandIterator,
    SessionState state,
    Uri script,
    Uri snapshot) async {
  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      () => developer.export(state, snapshot));
}
