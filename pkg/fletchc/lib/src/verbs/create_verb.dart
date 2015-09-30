// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.create_verb;

import 'dart:io' show
    File;

import 'infrastructure.dart';

import '../driver/developer.dart' show
    Settings,
    allocateWorker,
    createSessionState,
    parseSettings;

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

  await context.performTaskInWorker(
      new CreateSessionTask(name, sentence.withUri, sentence.base));

  return 0;
}

class CreateSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  final Uri settingsUri;

  final Uri base;

  const CreateSessionTask(this.name, this.settingsUri, this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return createSessionTask(name, settingsUri, base);
  }
}

Future<int> createSessionTask(String name, Uri settingsUri, Uri base) async {
  assert(SessionState.internalCurrent == null);
  Settings settings;
  if (settingsUri == null) {
    settingsUri = base.resolve('.fletch-settings');
    if (!await new File.fromUri(settingsUri).exists()) {
      settingsUri = null;
    }
  }
  if (settingsUri != null) {
    String jsonLikeData = await new File.fromUri(settingsUri).readAsString();
    settings = parseSettings(jsonLikeData, settingsUri);
  }
  SessionState state = createSessionState(name, settings);
  SessionState.internalCurrent = state;
  if (settingsUri != null) {
    state.log("created session with $settingsUri $settings");
  } else {
    state.log("created session");
  }
  return 0;
}