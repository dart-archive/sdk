// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.verb;

import 'dart:async' show
    Future;

import 'sentence_parser.dart' show
    Sentence;

export 'sentence_parser.dart' show
    Sentence;

import 'debug_verb.dart' show
    debugVerb;

import 'help_verb.dart' show
    helpVerb;

import 'compile_and_run_verb.dart' show
    compileAndRunVerb;

import 'shutdown_verb.dart' show
    shutdownVerb;

import 'create_verb.dart' show
    createVerb;

typedef Future<int> DoVerb(Sentence sentence, context);

class Verb {
  final DoVerb perform;
  final String documentation;

  /// True if this verb needs to run in a separate worker isolate.
  // TODO(ahe): Remove this option when all command-line processing is moved to
  // main isolate.
  final bool requiresWorker;

  const Verb(this.perform, this.documentation, {this.requiresWorker: false});
}

/// Common verbs are displayed in the default help screen.
///
/// Please make sure their combined documentation fit in in 80 columns by 20
/// lines.  The default terminal size is normally 80x24.  Two lines are used
/// for the prompts before and after running fletch.  Another two lines may be
/// used to print an error message.
const Map<String, Verb> commonVerbs = const <String, Verb>{
  "debug": debugVerb,
  "help": helpVerb,
};

/// Uncommon verbs aren't displayed in the normal help screen.
///
/// These verbs are displayed when running `fletch help all`.
const Map<String, Verb> uncommonVerbs = const <String, Verb>{
  "compile-and-run": compileAndRunVerb,

  "shutdown": shutdownVerb,
  "create": createVerb,
};
