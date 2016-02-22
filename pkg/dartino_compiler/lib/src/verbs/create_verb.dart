// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.create_verb;

import 'infrastructure.dart';

import '../worker/developer.dart' show
    Settings,
    allocateWorker,
    configFileUri,
    createSessionState,
    createSettings;

import 'documentation.dart' show
    createDocumentation;

const Action createAction = const Action(
    create, createDocumentation, requiresTargetSession: true,
    supportsWithUri: true);

Future<int> create(AnalyzedSentence sentence, VerbContext context) async {
  IsolatePool pool = context.pool;
  String name = sentence.targetName;

  UserSession session = await createSession(name, () => allocateWorker(pool));

  context = context.copyWithSession(session);

  return await context.performTaskInWorker(
      new CreateSessionTask(name, sentence.withUri, sentence.base));
}

class CreateSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  final Uri settingsUri;

  final Uri base;

  const CreateSessionTask(this.name, this.settingsUri, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return createSessionTask(
        commandSender, commandIterator, name, settingsUri, base);
  }
}

Future<int> createSessionTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    String name,
    Uri settingsUri,
    Uri base) async {
  assert(SessionState.internalCurrent == null);
  Settings settings = await createSettings(
      name, settingsUri, base, commandSender, commandIterator);
  SessionState state = createSessionState(name, settings);
  SessionState.internalCurrent = state;
  if (settingsUri != null) {
    state.log("created session with $settingsUri $settings");
  } else {
    state.log("created session with settings $settings");
  }
  return 0;
}
