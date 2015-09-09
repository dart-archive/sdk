// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_verb;

import 'infrastructure.dart';

import '../driver/developer.dart' as developer;

import 'documentation.dart' show
    compileDocumentation;

const Verb compileVerb = const Verb(
    compile, compileDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future<int> compile(AnalyzedSentence sentence, VerbContext context) {
  Uri script = sentence.targetUri;

  // This is asynchronous, but we don't await the result so we can respond to
  // other requests.
  context.performTaskInWorker(new CompileTask(script));

  return new Future<int>.value(null);
}

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  const CompileTask(this.script);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return compileTask(script);
  }
}

Future<int> compileTask(Uri script) {
  return developer.compile(script, SessionState.current);
}
