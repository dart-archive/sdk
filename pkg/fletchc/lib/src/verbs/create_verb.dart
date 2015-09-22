// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.create_verb;

import 'infrastructure.dart';

import '../driver/developer.dart' show
    allocateWorker,
    createSessionState;

import 'documentation.dart' show
    createDocumentation;

const Verb createVerb = const Verb(
    create, createDocumentation, requiresTargetSession: true);

Future<int> create(AnalyzedSentence sentence, VerbContext context) async {
  // TODO(ahe): packageConfig should be a user-configurable option.
  Uri packageConfig = sentence.base.resolve('.packages');
  IsolatePool pool = context.pool;
  String name = sentence.targetName;

  UserSession session = await createSession(name, () => allocateWorker(pool));

  context = context.copyWithSession(session);

  await context.performTaskInWorker(new CreateSessionTask(name, packageConfig));

  return 0;
}

class CreateSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  final Uri packageConfig;

  const CreateSessionTask(this.name, this.packageConfig);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return createSessionTask(name, packageConfig);
  }
}

Future<int> createSessionTask(String name, packageConfig) {
  assert(SessionState.internalCurrent == null);
  SessionState state = createSessionState(name, packageConfig);
  SessionState.internalCurrent = state;
  state.log("Created session '$name'.");
  return new Future<int>.value(0);
}
