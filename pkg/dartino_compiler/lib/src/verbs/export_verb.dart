// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.export_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    exportDocumentation;

import '../worker/developer.dart' show
    compileAndAttachToVmThen;

import '../worker/developer.dart' as developer;

const Action exportAction =
    const Action(
        export, exportDocumentation, requiresSession: true,
        requiresToUri: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> export(AnalyzedSentence sentence, VerbContext context) {
  return context.performTaskInWorker(
      new ExportTask(sentence.targetUri, sentence.toTargetUri, sentence.base));
}

class ExportTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  final Uri snapshot;

  final Uri base;

  const ExportTask(this.script, this.snapshot, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return exportTask(
        commandSender, commandIterator, SessionState.current, script, snapshot,
        base);
  }
}

Future<int> exportTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri snapshot,
    Uri base) async {
  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      true,
      () => developer.export(state, snapshot));
}
