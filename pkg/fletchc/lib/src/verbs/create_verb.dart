// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.create_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    TargetKind,
    Verb,
    VerbContext;

import '../driver/sentence_parser.dart' show
    NamedTarget;

import '../driver/session_manager.dart' show
    UserSession,
    createSession;

import '../driver/driver_main.dart' show
    ClientController,
    IsolateController,
    IsolatePool;

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

Future<int> create(Sentence sentence, VerbContext context) async {
  IsolatePool pool = context.pool;
  ClientController client = context.client;
  if (sentence.target != null &&
      sentence.target.kind == TargetKind.SESSION) {
    NamedTarget target = sentence.target;
    String name = target.name;
    checkNoPreposition(sentence);
    checkNoTailPreposition(sentence);
    checkNoTrailing(sentence);

    // Spawn/reuse a worker isolate.
    IsolateController worker =
        new IsolateController(await pool.getIsolate(exitOnError: false));

    await worker.beginSession();
    // TODO(ahe): Investigate why this message shows in client console, not
    // server console.
    client.log.note("Worker session started.");

    UserSession session = createSession(name, worker);
    print("Created session '${session.name}'.");
  }
  return 0;
}
