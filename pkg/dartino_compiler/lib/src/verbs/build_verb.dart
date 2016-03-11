// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.build_verb;

import 'infrastructure.dart';

import '../worker/developer.dart' show
    buildImage,
    compileAndAttachToVmThen,
    export,
    defaultSnapshotLocation;

import 'documentation.dart' show
    buildDocumentation;

const Action buildAction = const Action(
    buildFunction, buildDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future buildFunction(
    AnalyzedSentence sentence, VerbContext context) async {
  return context.performTaskInWorker(
      new BuildTask(sentence.targetUri, sentence.base));
}

class BuildTask extends SharedTask {
  final Uri script;
  final Uri base;

  BuildTask(this.script, this.base);

  Future call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) async {
    return buildTask(
        commandSender, commandIterator, SessionState.current, script, base);
  }
}

Future<int> buildTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri base) async {

  Uri snapshot = defaultSnapshotLocation(script);
  int rc = await compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      true,
      () => export(state, snapshot));
  return buildImage(commandSender, commandIterator, state, snapshot);
}
