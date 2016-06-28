// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.quit_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    quitDocumentation;

import '../hub/exit_codes.dart' show
    INPUT_ERROR;

const Action quitAction = const Action(quit, quitDocumentation);

Future<int> quit(AnalyzedSentence sentence, VerbContext context) async {
  throwFatalError(DiagnosticKind.quitTakesNoArguments);
  return INPUT_ERROR;
}
