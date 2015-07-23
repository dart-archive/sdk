// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.verbs;

import 'dart:async' show
    Future,
    StreamIterator;

import '../driver/sentence_parser.dart' show
    Sentence;

export '../driver/sentence_parser.dart' show
    PrepositionKind,
    Sentence,
    TargetKind;

import '../driver/driver_main.dart' show
    IsolatePool,
    ClientController;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

import '../driver/session_manager.dart' show
    UserSession;

import 'debug_verb.dart' show
    debugVerb;

import 'help_verb.dart' show
    helpVerb;

import 'show_verb.dart' show
    showVerb;

import 'compile_and_run_verb.dart' show
    compileAndRunVerb;

import 'shutdown_verb.dart' show
    shutdownVerb;

import 'create_verb.dart' show
    createVerb;

import 'compile_verb.dart' show
    compileVerb;

import 'attach_verb.dart' show
    attachVerb;

import 'run_verb.dart' show
    runVerb;

import 'x_end_verb.dart' show
    endVerb;

typedef Future<int> DoVerb(Sentence sentence, VerbContext context);

class Verb {
  final DoVerb perform;
  final String documentation;

  /// True if this verb needs to run in the context of a [UserSession].
  final bool requiresSession;

  const Verb(
      this.perform,
      this.documentation,
      {this.requiresSession: false});
}

abstract class VerbContext {
  final ClientController client;

  final IsolatePool pool;

  final UserSession session;

  VerbContext(this.client, this.pool, this.session);

  Future<Null> performTaskInWorker(SharedTask task);

  VerbContext copyWithSession(UserSession session);
}

/// Represents a task that is shared between the main isolate and a worker
/// isolate. Since instances of this class are copied from the main isolate to
/// a worker isolate, they should be kept simple:
///
/// *   Pay attention to the transitive closure of its fields. The closure
///     should be kept as small as possible to avoid too much copying.
///
/// *   Avoid enums and other compile-time constants in the transitive closure,
///     as they aren't canonicalized by the Dart VM, see issue 23244.
abstract class SharedTask {
  const SharedTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator);
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
  "show": showVerb
};

/// Uncommon verbs aren't displayed in the normal help screen.
///
/// These verbs are displayed when running `fletch help all`.
const Map<String, Verb> uncommonVerbs = const <String, Verb>{
  "compile-and-run": compileAndRunVerb,
  "shutdown": shutdownVerb,
  "create": createVerb,
  "compile": compileVerb,
  "attach": attachVerb,
  "x-run": runVerb,
  "x-end": endVerb,
};
