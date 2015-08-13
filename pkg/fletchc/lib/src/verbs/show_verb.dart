// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.show_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    showDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

const Verb showVerb =
    const Verb(show, showDocumentation, requiredTarget: TargetKind.ALL);

Future<int> show(AnalyzedSentence sentence, VerbContext context) async {
  throwInternalError("Show not yet implemented.");
}
