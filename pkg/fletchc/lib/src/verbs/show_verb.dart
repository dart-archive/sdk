// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.show_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    SharedTask,
    TargetKind,
    Verb,
    VerbContext;

// TODO: Move these out of create_verb when the next refactoring is complete.
import 'create_verb.dart' show
    checkNoPreposition,
    checkNoTailPreposition,
    checkNoTrailing;

import '../driver/sentence_parser.dart' show
    NamedTarget;

import 'documentation.dart' show
    showDocumentation;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwInternalError,
    throwFatalError;

const Verb showVerb = const Verb(show, showDocumentation);

Future<int> show(Sentence sentence, VerbContext context) async {
  if (sentence.target == null) {
    throwFatalError(
        DiagnosticKind.verbRequiresTarget, verb: sentence.verb);
  }
  NamedTarget target = sentence.target;
  String name = target.name;
  checkNoPreposition(sentence);
  checkNoTailPreposition(sentence);
  checkNoTrailing(sentence);

  throwInternalError("Show not yet implemented.");
}
