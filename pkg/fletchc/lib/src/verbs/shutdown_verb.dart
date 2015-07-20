// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.shutdown_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    Verb;

import '../driver/driver_main.dart' show
    gracefulShutdown;

import 'documentation.dart' show
    shutdownDocumentation;

const Verb shutdownVerb = const Verb(shutdown, shutdownDocumentation);

Future<int> shutdown(Sentence sentence, _) {
  gracefulShutdown();
  return new Future.value(0);
}
