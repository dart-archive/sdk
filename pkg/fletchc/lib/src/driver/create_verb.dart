// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.create_verb;

import 'dart:io' show
    exit;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    Verb;

const Verb createVerb = const Verb(create, documentation);

const String documentation = """
   create      Create something.
""";

Future<int> create(Sentence sentence, _) {
  return new Future.value(0);
}
