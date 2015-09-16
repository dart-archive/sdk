// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.export_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    exportDocumentation;

import '../driver/developer.dart' show
    compileAndAttachToLocalVmThen;

import '../driver/developer.dart' as developer;

const Verb exportVerb =
    const Verb(
        export, exportDocumentation, requiresSession: true,
        requiresToUri: true,
        supportedTargets: const <TargetKind>[TargetKind.FILE]);

Future<int> export(AnalyzedSentence sentence, VerbContext context) async {
  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(
      new ExportTask(
          sentence.programName, sentence.targetUri, sentence.toTargetUri));

  return null;
}

class ExportTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri programName;

  final Uri script;

  final Uri snapshot;

  const ExportTask(this.programName, this.script, this.snapshot);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return exportTask(
        commandSender, SessionState.current, programName, script, snapshot);
  }
}

Future<int> exportTask(
    CommandSender commandSender,
    SessionState state,
    Uri programName,
    Uri script,
    Uri snapshot) async {
  return compileAndAttachToLocalVmThen(
      commandSender,
      state,
      programName,
      script,
      () => developer.export(state, snapshot));
}
