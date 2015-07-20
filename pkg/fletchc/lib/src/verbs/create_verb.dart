// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.create_verb;

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
    createSession;

import '../driver/driver_main.dart' show
    ClientController,
    IsolateController,
    IsolatePool;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

import 'documentation.dart' show
    createDocumentation;

const Verb createVerb = const Verb(create, createDocumentation);

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

    Future<IsolateController> allocateWorker() async {
      IsolateController worker =
          new IsolateController(await pool.getIsolate(exitOnError: false));
      await worker.beginSession();
      client.log.note("Worker session '$name' started");
      return worker;
    }

    UserSession session = await createSession(name, allocateWorker);

    context = context.copyWithSession(session);

    await context.performTaskInWorker(new CreateSessionTask(name));
  }

  return 0;
}

class CreateSessionTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String name;

  const CreateSessionTask(this.name);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return createSessionTask(name);
  }
}

Future<int> createSessionTask(String name) {
  assert(SessionState.internalCurrent == null);
  SessionState.internalCurrent = new SessionState(name);
  print("Created session '$name'.");
  return new Future<int>.value(0);
}
