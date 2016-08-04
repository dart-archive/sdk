// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.complete_verb;

import '../hub/analytics.dart';
import 'actions.dart';
import 'documentation.dart' show completeDocumentation;
import 'infrastructure.dart';

const Action completeAction =
    const Action(performComplete, completeDocumentation, allowsTrailing: true);

Future<int> performComplete(
    AnalyzedSentence sentence, VerbContext context) async {
  List<String> words = sentence.trailing ?? <String>[];
  if (words.isNotEmpty && words.first == 'dartino') words.removeAt(0);
  var completions = <String>[];

  // complete verbs
  if (words.length < 2) {
    completions..addAll(commonActions.keys)..addAll(uncommonActions.keys);
    if (words.length == 1) {
      String prefix = words[0];
      completions.retainWhere((completion) => completion.startsWith(prefix));
    }
  }

  // echo results for the tab completion script
  completions
    ..sort()
    ..forEach((word) => print(word));

  // log the returned values
  context.clientConnection.analytics
      .logResponse(TAG_RESPONSE_COMPLETION, completions);

  return 0;
}
