// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.implementation;

import 'dart:async' show
    Future,
    StreamIterator;

export 'dart:async' show
    Future,
    StreamIterator;

// Don't export this.
import 'package:compiler/src/filenames.dart' show
    appendSlash;

// Don't export most of these.
import '../driver/sentence_parser.dart' show
    NamedTarget,
    Preposition,
    PrepositionKind,
    Verb,
    Sentence,
    Target,
    TargetKind;

export '../driver/sentence_parser.dart' show
    TargetKind;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

export '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender;

export '../driver/driver_commands.dart' show
    Command,
    CommandSender;

import '../driver/session_manager.dart' show
    FletchCompiler,
    FletchDelta,
    IncrementalCompiler,
    IsolateController,
    Session,
    SessionState,
    UserSession,
    currentSession;

export '../driver/session_manager.dart' show
    FletchCompiler,
    FletchDelta,
    IncrementalCompiler,
    IsolateController,
    Session,
    SessionState,
    UserSession,
    currentSession;

export '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

import '../driver/session_manager.dart' show
    SessionState,
    UserSession,
    createSession;

export '../driver/session_manager.dart' show
    SessionState,
    UserSession,
    createSession;

import '../driver/driver_main.dart' show
    ClientController,
    IsolatePool;

export '../driver/driver_main.dart' show
    ClientController,
    IsolatePool;

import '../diagnostic.dart' show
    throwInternalError; // TODO(ahe): Remove this.

import '../driver/session_manager.dart' show
    lookupSession; // Don't export this.

import 'actions.dart' show
    Action;

export 'actions.dart' show
    Action;

import 'documentation.dart' show
    helpDocumentation;

AnalyzedSentence analyzeSentence(Sentence sentence) {
  Uri base = Uri.base;
  if (sentence.currentDirectory != null) {
    base = fileUri(appendSlash(sentence.currentDirectory), base);
  }
  Verb verb = sentence.verb;
  Action action = verb.action;

  if (sentence.target != null && sentence.target.kind == TargetKind.HELP) {
    Action contextHelp = new Action((_,__) async {
      print(action.documentation);
      return 0;
    }, null);
    return new AnalyzedSentence(
      new Verb(verb.name, contextHelp), null, null, null, null, null,
      null, null, null, null, null, null);
  }

  Preposition preposition = sentence.preposition;
  if (preposition == null) {
    preposition = sentence.tailPreposition;
  } else if (sentence.tailPreposition != null) {
    throwInternalError(
        "Can't use both '$preposition', and '${sentence.tailPreposition}'");
  }

  Target target = sentence.target;

  List<String> trailing = sentence.trailing;

  NamedTarget sessionTarget;

  if (preposition != null &&
      preposition.kind == PrepositionKind.IN &&
      preposition.target.kind == TargetKind.SESSION) {
    sessionTarget = preposition.target;
  }

  if (!action.allowsTrailing) {
    if (trailing != null) {
      throwInternalError("Unexpected arguments: ${trailing.join(' ')}");
    }
  }

  if (target != null &&
      action.requiredTarget == null &&
      action.supportedTargets == null) {
    throwInternalError("Can't use '$target' with '$verb'");
  }

  Uri toTargetUri;
  Uri withUri;
  if (action.requiresToUri) {
    if (preposition == null) {
      throwFatalError(DiagnosticKind.missingToFile);
    }
    if (preposition.kind != PrepositionKind.TO) {
      throwFatalError(
          DiagnosticKind.expectedToPreposition, preposition: preposition);
    }
    if (preposition.target.kind != TargetKind.FILE) {
      throwFatalError(
          DiagnosticKind.expectedFileTarget, target: preposition.target);
    }
    NamedTarget target = preposition.target;
    toTargetUri = fileUri(target.name, base);
  } else if (sessionTarget != null) {
    if (!action.requiresSession) {
      throwFatalError(
          DiagnosticKind.verbRequiresNoSession, verb: verb,
          sessionName: sessionTarget.name);
    }
  } else if (preposition != null) {
    if (action.supportsWithUri &&
        preposition.kind == PrepositionKind.WITH &&
        preposition.target.kind == TargetKind.FILE) {
      NamedTarget target = preposition.target;
      withUri = fileUri(target.name, base);
    } else {
      throwInternalError("Can't use '$preposition' with '$verb'");
    }
  }

  if (action.requiredTarget != null) {
    if (target == null) {
      switch (action.requiredTarget) {
        case TargetKind.TCP_SOCKET:
          throwFatalError(DiagnosticKind.noTcpSocketTarget);
          break;

        case TargetKind.FILE:
          throwFatalError(DiagnosticKind.noFileTarget);
          break;

        default:
          if (action.requiresTargetSession) {
            throwFatalError(
                DiagnosticKind.verbRequiresSessionTarget, verb: verb);
          } else {
            // TODO(ahe): Turn into a DiagnosticKind when we actually have a
            // verb that can provoke this error.
            throwInternalError(
                "Can't perform '$verb' without a target. "
                "Try adding a thing or group of things.");
          }
          break;
      }
    } else if (target.kind != action.requiredTarget) {
      switch (action.requiredTarget) {
        case TargetKind.TCP_SOCKET:
          throwFatalError(
              DiagnosticKind.verbRequiresSocketTarget,
              verb: verb, target: sentence.target);
          break;

        case TargetKind.FILE:
          throwFatalError(
              DiagnosticKind.verbRequiresFileTarget,
              verb: verb, target: sentence.target);
          break;

        default:
          throwInternalError("$verb requires a ${action.requiredTarget}");
      }
    }
  }

  if (action.supportedTargets != null && target != null) {
    if (!action.supportedTargets.contains(target.kind)) {
      throwFatalError(
          DiagnosticKind.verbDoesNotSupportTarget, verb: verb, target: target);
    }
  }

  String sessionName;
  if (sessionTarget != null) {
    sessionName = sessionTarget.name;
  } else if (action.requiresSession) {
    sessionName = currentSession;
  }

  String targetName;
  Uri targetUri;
  if (target is NamedTarget) {
    targetName = target.name;
    if (target.kind == TargetKind.FILE) {
      targetUri = fileUri(targetName, base);
    }
  }

  Uri programName =
      sentence.programName == null ? null : fileUri(sentence.programName, base);
  return new AnalyzedSentence(
      verb, target, targetName, preposition, trailing, sessionName,
      sentence.arguments, base, programName, targetUri, toTargetUri, withUri);
}

Uri fileUri(String path, Uri base) => base.resolveUri(new Uri.file(path));

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

class AnalyzedSentence {
  final Verb verb;

  final Target target;

  final String targetName;

  final Preposition preposition;

  final List<String> trailing;

  final String sessionName;

  // TODO(ahe): Remove when compile-and-run is removed.
  final List<String> arguments;

  /// The current working directory of the C++ client.
  final Uri base;

  final Uri programName;

  /// Value of 'file NAME' converted to a Uri (main target, no preposition).
  final Uri targetUri;

  /// Value of 'to file NAME' converted to a Uri.
  final Uri toTargetUri;

  /// Value of 'with <URI>' converted to a Uri.
  final Uri withUri;

  AnalyzedSentence(
      this.verb,
      this.target,
      this.targetName,
      this.preposition,
      this.trailing,
      this.sessionName,
      this.arguments,
      this.base,
      this.programName,
      this.targetUri,
      this.toTargetUri,
      this.withUri);

  Future<int> performVerb(VerbContext context) {
    return verb.action.perform(this, context);
  }
}
