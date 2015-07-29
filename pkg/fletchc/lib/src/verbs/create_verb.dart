// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.create_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    createDocumentation;

const Verb createVerb = const Verb(
    create, createDocumentation, requiresTargetSession: true);

Future<int> create(AnalyzedSentence sentence, VerbContext context) async {
  IsolatePool pool = context.pool;
  ClientController client = context.client;
  String name = sentence.targetName;

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

  // TODO(ahe): Allow user to specify dart2js options.
  List<String> compilerOptions = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compilerHelper = new FletchCompiler(
      options: compilerOptions,
      // TODO(ahe): packageRoot should be a user provided option.
      packageRoot: 'package/');

  SessionState.internalCurrent = new SessionState(
      name, compilerHelper, compilerHelper.newIncrementalCompiler());

  print("Created session '$name'.");
  return new Future<int>.value(0);
}
