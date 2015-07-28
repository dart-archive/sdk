// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.end_verb;

import 'infrastructure.dart';

import '../driver/session_manager.dart' show
    endSession;

import 'documentation.dart' show
    endDocumentation;

const Verb endVerb =
    const Verb(end, endDocumentation, requiresTargetSession: true);

Future<int> end(AnalyzedSentence sentence, VerbContext context) async {
  String name = sentence.targetName;
  UserSession session = endSession(name);
  context = context.copyWithSession(session);
  await session.worker.performTask(
      new EndSessionTask(name), context.client, endSession: true);

  return null;
}

class EndSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  const EndSessionTask(this.name);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return endSessionTask(name);
  }
}

Future<int> endSessionTask(String name) {
  assert(SessionState.internalCurrent.name == name);
  SessionState.internalCurrent = null;
  print("Ended session '$name'.");
  return new Future<int>.value(0);
}
