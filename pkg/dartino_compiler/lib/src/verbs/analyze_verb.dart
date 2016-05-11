// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.analyze_verb;

import '../worker/developer.dart' as developer;

import 'documentation.dart' show
    analyzeDocumentation;

import 'infrastructure.dart';

const Action analyzeAction = const Action(performAnalysis, analyzeDocumentation,
    requiresSession: true, requiredTarget: TargetKind.FILE);

Future<int> performAnalysis(
    AnalyzedSentence sentence, VerbContext context) async {
  return context
      .performTaskInWorker(new AnalyzeTask(sentence.targetUri, sentence.base));
}

class AnalyzeTask extends SharedTask {
  final Uri targetUri;
  final Uri base;

  const AnalyzeTask(this.targetUri, this.base);

  Future<int> call(CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return analyzeTask(targetUri, base);
  }
}

Future<int> analyzeTask(Uri targetUri, Uri base) {
  return developer.analyze(targetUri, SessionState.current, base);
}

