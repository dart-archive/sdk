// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.help_verb;

import 'infrastructure.dart';

import 'actions.dart' show
    commonActions,
    uncommonActions;

import 'documentation.dart' show
    helpDocumentation,
    synopsis;

const Action helpAction =
    const Action(
        help, helpDocumentation,
        supportedTargets: const [ TargetKind.ALL ], allowsTrailing: true);

Future<int> help(AnalyzedSentence sentence, _) async {
  int exitCode = 0;
  bool showAllActions = sentence.target != null;
  if (sentence.trailing != null) {
    exitCode = 1;
  }
  if (sentence.verb.name != "help") {
    exitCode = 1;
  }
  print(generateHelpText(showAllActions));
  return exitCode;
}

String generateHelpText(bool showAllActions) {
  List<String> helpStrings = <String>[synopsis];
  addAction(String name, Action action) {
    helpStrings.add("");
    List<String> lines = action.documentation.trimRight().split("\n");
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.length > 80) {
        throw new StateError(
            "Line ${i+1} of Action '$name' is too long and may not be "
            "visible in a normal terminal window: $line\n"
            "Please trim to 80 characters or fewer.");
      }
      helpStrings.add(lines[i]);
    }
  }
  List<String> names = <String>[]..addAll(commonActions.keys);
  if (showAllActions) {
    names.addAll(uncommonActions.keys);
  }
  if (showAllActions) {
    names.sort();
  }
  for (String name in names) {
    Action action = commonActions[name];
    if (action == null) {
      action = uncommonActions[name];
    }
    addAction(name, action);
  }

  if (!showAllActions && helpStrings.length > 20) {
    throw new StateError(
        "More than 20 lines in the combined documentation of [commonActions]. "
        "The documentation may scroll out of view:\n${helpStrings.join('\n')}."
        "Can you shorten the documentation?");
  }
  return helpStrings.join("\n");
}
