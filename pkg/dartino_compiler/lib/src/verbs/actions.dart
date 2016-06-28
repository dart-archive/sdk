// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.verbs;

import 'infrastructure.dart' show
    AnalyzedSentence,
    Future,
    TargetKind,
    VerbContext;

import 'analyze_verb.dart' show
    analyzeAction;

import 'attach_verb.dart' show
    attachAction;

import 'build_verb.dart' show
    buildAction;

import 'compile_verb.dart' show
    compileAction;

import 'create_verb.dart' show
    createAction;

import 'debug_verb.dart' show
    debugAction;

import 'disable_verb.dart' show
    disableAction;

import 'emulate_verb.dart' show
    emulateAction;

import 'enable_verb.dart' show
    enableAction;

import 'export_verb.dart' show
    exportAction;

import 'flash_verb.dart' show
    flashAction;

import 'help_verb.dart' show
    helpAction;

import 'run_verb.dart' show
    runAction;

import 'x_end_verb.dart' show
    endAction;

import 'x_upgrade_verb.dart' show
    upgradeAction;

import 'x_download_tools_verb.dart' show
    downloadToolsAction;

import 'x_should_prompt_analytics_verb.dart' show
    shouldPromptAnalyticsAction;

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

  /// True if this verb needs "for NAME".
  final bool requiresForName;

  /// True if this verb requires a session target (that is, "session NAME"
  /// without "in").
  final bool requiresTargetSession;

  /// True if this verb allows trailing arguments.
  final bool allowsTrailing;

  /// Optional kind of target required by this verb.
  final TargetKind requiredTarget;

  /// Indicates whether the action needs a target. If [requiredTarget] is
  /// non-null, this flag is set to `true`, regardless of the value given
  /// in the constructor.
  final bool requiresTarget;

  /// Optional list of targets supported (but not required) by this verb.
  final List<TargetKind> supportedTargets;

  /// True if this verb supports "with <URI>"
  final bool supportsWithUri;

  final bool supportsOn;

  const Action(
      this.perform,
      this.documentation,
      {this.requiresSession: false,
       this.requiresToUri: false,
       this.requiresForName: false,
       this.allowsTrailing: false,
       TargetKind requiredTarget,
       bool requiresTarget: false,
       this.supportedTargets,
       this.supportsWithUri: false,
       this.supportsOn: false})
      : this.requiresTargetSession =
          identical(requiredTarget, TargetKind.SESSION),
        this.requiredTarget = requiredTarget,
        requiresTarget = !identical(requiredTarget, null) || requiresTarget;
}

/// Use a [ActionGroup] to group actions that share the same primary verb
/// such as "create project" and "create session".
class ActionGroup extends Action {
  final Map<String, Action> actions;

  const ActionGroup(Map<String, Action> actions, String documentation)
      : super(null, documentation),
        this.actions = actions;
}


// TODO(ahe): Support short and long documentation.

/// Common actions are displayed in the default help screen.
///
/// Please make sure their combined documentation fit in in 80 columns by 20
/// lines.  The default terminal size is normally 80x24.  Two lines are used
/// for the prompts before and after running dartino.  Another two lines may be
/// used to print an error message.
const Map<String, Action> commonActions = const <String, Action>{
  "help": helpAction,
  "run": runAction,
  "show": showAction,
  "quit": quitAction,
};

/// Uncommon verbs aren't displayed in the normal help screen.
///
/// These verbs are displayed when running `dartino help all`.
const Map<String, Action> uncommonActions = const <String, Action>{
  "analyze": analyzeAction,
  "attach": attachAction,
  "build": buildAction,
  "compile": compileAction,
  "create": createAction,
  "debug": debugAction,
  "disable": disableAction,
  "enable": enableAction,
  "export": exportAction,
  "flash": flashAction,
  "x-download-tools": downloadToolsAction,
  "x-emulate": emulateAction,
  "x-end": endAction,
  "x-should-prompt-analytics": shouldPromptAnalyticsAction,
  "x-upgrade": upgradeAction,
};
