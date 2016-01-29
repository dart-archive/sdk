// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests for verbs.
library fletch_tests.verb_tests;

import 'dart:async' show
    Future;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/verbs/help_verb.dart' as help_verb;

/// Test verifies that the help text is the right shape.
///
/// The documentation should fit into 80 columns by 20 lines.
/// The default terminal size is normally 80x24.  Two lines are used for the
/// prompts before and after running fletch.  Another two lines may be
/// used to print an error message.
///
/// See commonActions in package:fletchc/src/verbs/actions.dart.
Future testHelpTextFormatCompliance() async {

  // The generation of the help text will self check format compliance.
  help_verb.generateHelpText(true);
  help_verb.generateHelpText(false);
}
