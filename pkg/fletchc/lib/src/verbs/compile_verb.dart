// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.compile_verb;

import 'infrastructure.dart';

import '../worker/developer.dart' as developer;

import 'documentation.dart' show
    compileDocumentation;

const Action compileAction = const Action(
    compile, compileDocumentation, requiresSession: true,
    requiredTarget: TargetKind.FILE);

Future<int> compile(AnalyzedSentence sentence, VerbContext context) {
  bool analyzeOnly = sentence.options.analyzeOnly;
  bool fatalIncrementalFailures = sentence.options.fatalIncrementalFailures;
  return context.performTaskInWorker(
      new CompileTask(sentence.targetUri, sentence.base, analyzeOnly,
          fatalIncrementalFailures));
}

class CompileTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri script;

  final Uri base;

  final bool analyzeOnly;

  final bool fatalIncrementalFailures;

  const CompileTask(
      this.script, this.base, this.analyzeOnly, this.fatalIncrementalFailures);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return compileTask(script, base, analyzeOnly, fatalIncrementalFailures);
  }
}

Future<int> compileTask(
    Uri script, Uri base, bool analyzeOnly, bool fatalIncrementalFailures) {
  return developer.compile(
      script, SessionState.current, base, analyzeOnly: analyzeOnly,
      fatalIncrementalFailures: fatalIncrementalFailures);
}
