// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Future;

import 'package:fletchc/src/driver/sentence_parser.dart';

import 'package:expect/expect.dart';

Future main() {
  Sentence sentence;

  void checkVerb(String name) {
    Expect.isNotNull(sentence.verb);
    Expect.stringEquals(name, sentence.verb.name);
    print("Verb '$name' as expected.");
  }

  void checkTarget(String noun) {
    Expect.isNotNull(sentence.target);
    Expect.stringEquals(noun, sentence.target.noun);
    print("Target '$noun' as expected.");
  }

  void checkNamedTarget(String noun, String name) {
    Expect.isNotNull(sentence.target);
    NamedTarget namedTarget = sentence.target;
    Expect.stringEquals(noun, namedTarget.noun);
    Expect.stringEquals(name, namedTarget.name);
    print("NamedTarget '$noun $name' as expected.");
  }

  void checkNoTarget() {
    Expect.isNull(sentence.target);
    print("No target as expected.");
  }

  sentence = parseSentence([]);
  print(sentence);
  checkVerb('help');
  Expect.isNull(sentence.preposition);
  checkNoTarget();
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['not_a_verb']);
  print(sentence);
  checkVerb('not_a_verb');
  Expect.isNull(sentence.preposition);
  checkNoTarget();
  Expect.isNull(sentence.tailPreposition);
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['not_a_verb'], sentence.trailing);

  sentence = parseSentence(['create', 'session', 'fisk']);
  print(sentence);
  checkVerb('create');
  Expect.isNull(sentence.preposition);
  checkNamedTarget('session', 'fisk');
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
    NamedTarget namedTarget = preposition.target;
    Expect.isNotNull(namedTarget);
    Expect.stringEquals('session', namedTarget.noun);
    Expect.stringEquals('fisk', namedTarget.name);
    checkNamedTarget('class', 'Foo');
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
  checkVerb('create');
  Expect.isNotNull(sentence.preposition);
  Expect.stringEquals('in', sentence.preposition.word);
  Expect.isTrue(sentence.preposition.target is ErrorTarget);
  checkNoTarget();
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  sentence = parseSentence(['create', 'in', 'fisk', 'fisk']);
  print(sentence);
  checkVerb('create');
  Expect.isNotNull(sentence.preposition);
  Expect.stringEquals('in', sentence.preposition.word);
  Expect.isTrue(sentence.preposition.target is ErrorTarget);
  checkNoTarget();
  Expect.isNull(sentence.tailPreposition);
  Expect.isNotNull(sentence.trailing);
  Expect.listEquals(['fisk'], sentence.trailing);

  sentence = parseSentence(['help', 'all']);
  print(sentence);
  checkVerb('help');
  Expect.isNull(sentence.preposition);
  checkTarget('all');
  Expect.isNull(sentence.tailPreposition);
  Expect.isNull(sentence.trailing);

  return new Future.value();
}
