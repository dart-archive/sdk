// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.create_verb;

import 'dart:io' show
    exit;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    TargetKind,
    Verb;

import 'sentence_parser.dart' show
    NamedTarget;

import 'session_manager.dart' show
    UserSession,
    createSession;

const Verb createVerb = const Verb(create, documentation);

const String documentation = """
   create      Create something.
""";

void checkNoPreposition(Sentence sentence) {
  if (sentence.preposition != null) {
    // TODO(ahe): Improve this.
    print("Ignoring ${sentence.preposition}.");
  }
}

void checkNoTailPreposition(Sentence sentence) {
  if (sentence.tailPreposition != null) {
    // TODO(ahe): Improve this.
    print("Ignoring ${sentence.tailPreposition}.");
  }
}

void checkNoTrailing(Sentence sentence) {
  if (sentence.trailing != null) {
    // TODO(ahe): Improve this.
    print("Ignoring: ${sentence.trailing.join(' ')}.");
  }
}

Future<int> create(Sentence sentence, _) {
  if (sentence.target != null &&
      sentence.target.kind == TargetKind.SESSION) {
    NamedTarget target = sentence.target;
    String name = target.name;
    checkNoPreposition(sentence);
    checkNoTailPreposition(sentence);
    checkNoTrailing(sentence);
    UserSession session = createSession(name);
    print("Created session '${session.name}'.");
  }
  return new Future.value(0);
}
