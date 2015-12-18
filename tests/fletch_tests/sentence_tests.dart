// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Future;

import 'package:fletchc/src/hub/sentence_parser.dart';

import 'package:expect/expect.dart';

Future main() {
  Sentence sentence;

  void checkAction(String name) {
    Expect.isNotNull(sentence.verb);
    Expect.stringEquals(name, sentence.verb.name);
    print("Action '$name' as expected.");
  }

  void checkTarget(TargetKind kind) {
    Expect.isNotNull(sentence.targets.single);
    Expect.equals(kind, sentence.targets.single.kind);
    print("Target '$kind' as expected.");
  }

  void checkNamedTarget(TargetKind kind, String name) {
    Expect.isNotNull(sentence.targets.single);
    NamedTarget namedTarget = sentence.targets.single;
    Expect.equals(kind, namedTarget.kind);
    Expect.stringEquals(name, namedTarget.name);
    print("NamedTarget '$kind $name' as expected.");
  }

  void checkNoTarget() {
    Expect.isTrue(sentence.targets.isEmpty);
    print("No target as expected.");
  }

  sentence = parseSentence([]);
  print(sentence);
  checkAction('help');
  Expect.isTrue(sentence.prepositions.isEmpty);
  checkNoTarget();
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['not_a_verb']);
  print(sentence);
  checkAction('not_a_verb');
  Expect.isTrue(sentence.prepositions.isEmpty);
  checkNoTarget();
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['not_a_verb'], sentence.trailing);

  sentence = parseSentence(['create', 'session', 'fisk']);
  print(sentence);
  checkAction('create');
  Expect.isTrue(sentence.prepositions.isEmpty);
  checkNamedTarget(TargetKind.SESSION, 'fisk');
  Expect.isNull(sentence.trailing);

  void checkCreateFooInFisk() {
    Expect.isNotNull(sentence.verb);
    Expect.stringEquals('create', sentence.verb.name);
    Preposition preposition = sentence.prepositions.single;
    Expect.isNotNull(preposition);
    Expect.equals(PrepositionKind.IN, preposition.kind);
    NamedTarget namedTarget = preposition.target;
    Expect.isNotNull(namedTarget);
    Expect.equals(TargetKind.SESSION, namedTarget.kind);
    Expect.stringEquals('fisk', namedTarget.name);
    checkNamedTarget(TargetKind.CLASS, 'Foo');
    Expect.isNull(sentence.trailing);
  }
  sentence = parseSentence(['create', 'in', 'session', 'fisk', 'class', 'Foo']);
  print(sentence);
  checkCreateFooInFisk();

  sentence = parseSentence(['create', 'class', 'Foo', 'in', 'session', 'fisk']);
  print(sentence);
  checkCreateFooInFisk();

  sentence = parseSentence(['create', 'in', 'fisk']);
  print(sentence);
  checkAction('create');
  Expect.isNotNull(sentence.prepositions.single);
  Expect.equals(PrepositionKind.IN, sentence.prepositions.single.kind);
  Expect.isTrue(sentence.prepositions.single.target is ErrorTarget);
  checkNoTarget();
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['create', 'in', 'fisk', 'fisk']);
  print(sentence);
  checkAction('create');
  Expect.isNotNull(sentence.prepositions.single);
  Expect.equals(PrepositionKind.IN, sentence.prepositions.single.kind);
  Expect.isTrue(sentence.prepositions.single.target is ErrorTarget);
  checkNoTarget();
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['fisk'], sentence.trailing);

  sentence = parseSentence(['help', 'all']);
  print(sentence);
  checkAction('help');
  Expect.isTrue(sentence.prepositions.isEmpty);
  checkTarget(TargetKind.ALL);
  Expect.isNull(sentence.trailing);

  return new Future.value();
}
