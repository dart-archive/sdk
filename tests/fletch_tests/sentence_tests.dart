// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Future;

import 'package:fletchc/src/driver/sentence_parser.dart';

import 'package:expect/expect.dart';

Future main() {
  Sentence sentence;
  NamedTarget namedTarget;

  sentence = parseSentence([]);
  print(sentence);
  Expect.isNotNull(sentence.verb);
  Expect.stringEquals('help', sentence.verb.name);
  Expect.isNull(sentence.preposition);
  Expect.isNull(sentence.target);
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['not_a_verb']);
  print(sentence);
  Expect.isNotNull(sentence.verb);
  Expect.stringEquals('not_a_verb', sentence.verb.name);
  Expect.isNull(sentence.preposition);
  Expect.isNull(sentence.target);
  Expect.isNull(sentence.tailPreposition);
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['not_a_verb'], sentence.trailing);

  sentence = parseSentence(['create', 'session', 'fisk']);
  print(sentence);
  Expect.isNotNull(sentence.verb);
  Expect.stringEquals('create', sentence.verb.name);
  Expect.isNull(sentence.preposition);
  namedTarget = sentence.target;
  Expect.isNotNull(namedTarget);
  Expect.stringEquals('session', namedTarget.noun);
  Expect.stringEquals('fisk', namedTarget.name);
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  void checkCreateFooInFisk(bool tail) {
    Expect.isNotNull(sentence.verb);
    Expect.stringEquals('create', sentence.verb.name);
    Preposition preposition;
    if (tail) {
      preposition = sentence.tailPreposition;
      Expect.isNull(sentence.preposition);
    } else {
      preposition = sentence.preposition;
      Expect.isNull(sentence.tailPreposition);
    }
    Expect.isNotNull(preposition);
    Expect.stringEquals('in', preposition.word);
    namedTarget = preposition.target;
    Expect.isNotNull(namedTarget);
    Expect.stringEquals('session', namedTarget.noun);
    Expect.stringEquals('fisk', namedTarget.name);
    namedTarget = sentence.target;
    Expect.isNotNull(namedTarget);
    Expect.stringEquals('class', namedTarget.noun);
    Expect.stringEquals('Foo', namedTarget.name);
    Expect.isNull(sentence.trailing);
  }
  sentence = parseSentence(['create', 'in', 'session', 'fisk', 'class', 'Foo']);
  print(sentence);
  checkCreateFooInFisk(false);

  sentence = parseSentence(['create', 'class', 'Foo', 'in', 'session', 'fisk']);
  print(sentence);
  checkCreateFooInFisk(true);

  sentence = parseSentence(['create', 'in', 'fisk']);
  print(sentence);
  Expect.isNotNull(sentence.verb);
  Expect.stringEquals('create', sentence.verb.name);
  Expect.isNotNull(sentence.preposition);
  Expect.stringEquals('in', sentence.preposition.word);
  Expect.isTrue(sentence.preposition.target is ErrorTarget);
  Expect.isNull(sentence.target);
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['create', 'in', 'fisk', 'fisk']);
  print(sentence);
  Expect.isNotNull(sentence.verb);
  Expect.stringEquals('create', sentence.verb.name);
  Expect.isNotNull(sentence.preposition);
  Expect.stringEquals('in', sentence.preposition.word);
  Expect.isTrue(sentence.preposition.target is ErrorTarget);
  Expect.isNull(sentence.target);
  Expect.isNull(sentence.tailPreposition);
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['fisk'], sentence.trailing);

  return new Future.value();
}
