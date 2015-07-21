// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.end_verb;

import 'dart:async' show
    Future,
    StreamIterator;

import 'verbs.dart' show
    Sentence,
    SharedTask,
    TargetKind,
    Verb,
    VerbContext;

import '../driver/sentence_parser.dart' show
    NamedTarget;

import '../driver/session_manager.dart' show
    SessionState,
    UserSession,
    endSession;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

import 'documentation.dart' show
    endDocumentation;

import 'create_verb.dart' show
    checkNoPreposition,
    checkNoTailPreposition,
    checkNoTrailing;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

const Verb endVerb = const Verb(end, endDocumentation);

Future<int> end(Sentence sentence, VerbContext context) async {
  if (sentence.target == null ||
      sentence.target.kind != TargetKind.SESSION) {
    throwFatalError(
        DiagnosticKind.verbRequiresSessionTarget, verb: sentence.verb);
  }

  NamedTarget target = sentence.target;
  String name = target.name;
  checkNoPreposition(sentence);
  checkNoTailPreposition(sentence);
  checkNoTrailing(sentence);

  UserSession session = endSession(name);

  context = context.copyWithSession(session);

  await session.worker.performTask(
      new EndSessionTask(name), context.client, endSession: true);

  return 0;
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
