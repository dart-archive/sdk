// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.x_discover_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    discoverDocumentation;

import '../driver/developer.dart' show
    discoverDevices;

const Action discoverAction =
    const Action(discover, discoverDocumentation);

Future<int> discover(AnalyzedSentence sentence, VerbContext context) async {
  await discoverDevices();
  return 1;
}
