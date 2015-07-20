// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.debug_verb;

import 'dart:async' show
    Future;

import 'verbs.dart' show
    Sentence,
    Verb;

import '../diagnostic.dart' show
    throwInternalError;

const Verb debugVerb = const Verb(debug, documentation);

const String documentation = """
   debug [command]
             Perform a debug command, or if none are specified start an
             interactive debug session.
""";

Future debug(Sentence sentence, _) async {
  throwInternalError("Debug action not yet implemented.");
}
