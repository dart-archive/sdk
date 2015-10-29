// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.verbs;

import 'infrastructure.dart' show
    AnalyzedSentence,
    Future,
    TargetKind,
    VerbContext;

import 'attach_verb.dart' show
    attachAction;

import 'compile_verb.dart' show
    compileAction;

import 'create_verb.dart' show
    createAction;

import 'debug_verb.dart' show
    debugAction;

import 'export_verb.dart' show
    exportAction;

import 'help_verb.dart' show
    helpAction;

import 'run_verb.dart' show
    runAction;

import 'shutdown_verb.dart' show
    shutdownAction;

import 'x_end_verb.dart' show
    endAction;

import 'x_servicec_verb.dart' show
    servicecAction;

import 'x_upgrade_verb.dart' show
    upgradeAction;

import 'quit_verb.dart' show
    quitAction;

import 'show_verb.dart' show
    showAction;

typedef Future<int> DoAction(AnalyzedSentence sentence, VerbContext context);

class Action {
  final DoAction perform;

  final String documentation;

  /// True if this verb needs "in session NAME".
  final bool requiresSession;

  /// True if this verb needs "to file NAME".
  // TODO(ahe): Should be "to uri NAME".
  final bool requiresToUri;

  /// True if this verb requires a session target (that is, "session NAME"
  /// without "in").
  final bool requiresTargetSession;

  /// True if this verb allows trailing arguments.
  final bool allowsTrailing;

  /// Optional kind of target required by this verb.
  final TargetKind requiredTarget;

  /// Optional list of targets supported (but not required) by this verb.
  final List<TargetKind> supportedTargets;

  /// True if this verb supports "with <URI>"
  final bool supportsWithUri;

  const Action(
      this.perform,
      this.documentation,
      {this.requiresSession: false,
       this.requiresToUri: false,
       this.allowsTrailing: false,
       bool requiresTargetSession: false,
       TargetKind requiredTarget,
       this.supportedTargets,
       this.supportsWithUri: false})
      : this.requiresTargetSession = requiresTargetSession,
        this.requiredTarget =
            requiresTargetSession ? TargetKind.SESSION : requiredTarget;
}


// TODO(ahe): Support short and long documentation.

/// Common verbs are displayed in the default help screen.
///
/// Please make sure their combined documentation fit in in 80 columns by 20
/// lines.  The default terminal size is normally 80x24.  Two lines are used
/// for the prompts before and after running fletch.  Another two lines may be
/// used to print an error message.
const Map<String, Action> commonActions = const <String, Action>{
  "help": helpAction,
  "attach": attachAction,
  "run": runAction,
  "export": exportAction,
};

/// Uncommon verbs aren't displayed in the normal help screen.
///
/// These verbs are displayed when running `fletch help all`.
const Map<String, Action> uncommonActions = const <String, Action>{
  "compile": compileAction,
  "create": createAction,
  "debug": debugAction,
  "shutdown": shutdownAction,
  "x-end": endAction,
  "x-servicec": servicecAction,
  "x-upgrade": upgradeAction,
  "quit": quitAction,
  "show": showAction,
};
