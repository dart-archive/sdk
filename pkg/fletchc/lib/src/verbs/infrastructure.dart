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

// Don't export most of these.
import '../driver/sentence_parser.dart' show
    NamedTarget,
    Preposition,
    PrepositionKind,
    ResolvedVerb,
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
    FletchVmSession,
    IncrementalCompiler,
    IsolateController,
    SessionState,
    UserSession;

export '../driver/session_manager.dart' show
    FletchCompiler,
    FletchDelta,
    FletchVmSession,
    IncrementalCompiler,
    IsolateController,
    SessionState,
    UserSession;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

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

export 'verbs.dart' show
    Verb;

AnalyzedSentence analyzeSentence(Sentence sentence) {
  ResolvedVerb verb = sentence.verb;

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

  if (!verb.verb.allowsTrailing) {
    if (trailing != null) {
      throwInternalError("Unexpected arguments: ${trailing.join(' ')}");
    }
  }

  if (target != null &&
      !verb.verb.requiresTarget &&
      verb.verb.supportsTarget == null) {
    throwInternalError("Can't use '$target' with '$verb'");
  }

  if (sessionTarget != null) {
    if (!verb.verb.requiresSession) {
      throwFatalError(
          DiagnosticKind.verbRequiresNoSession, verb: verb,
          sessionName: sessionTarget.name);
    }
  } else if (preposition != null) {
    throwInternalError("Can't use '$preposition' with '$verb'");
  }

  if (verb.verb.requiresTarget) {
    if (target == null) {
      switch (verb.verb.supportsTarget) {
        case TargetKind.TCP_SOCKET:
          throwFatalError(DiagnosticKind.noTcpSocketTarget);
          break;

        case TargetKind.FILE:
          throwFatalError(DiagnosticKind.noFileTarget);
          break;

        default:
          if (verb.verb.requiresTargetSession) {
            throwFatalError(
                DiagnosticKind.verbRequiresSessionTarget, verb: verb);
          } else {
            throwFatalError(DiagnosticKind.verbRequiresTarget, verb: verb);
          }
          break;
      }
    }
  }

  if (verb.verb.supportsTarget != null && target != null) {
    if (target.kind != verb.verb.supportsTarget) {
      switch (verb.verb.supportsTarget) {
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
          throwInternalError("$verb requires a ${verb.verb.supportsTarget}");
      }
    }
  }


  UserSession session;
  if (sessionTarget != null) {
    String sessionName = sessionTarget.name;
    session = lookupSession(sessionName);
    if (session == null) {
      throwFatalError(DiagnosticKind.noSuchSession, sessionName: sessionName);
    }
  } else if (verb.verb.requiresSession) {
    throwFatalError(DiagnosticKind.verbRequiresSession, verb: verb);
  }

  String targetName;
  if (target is NamedTarget) {
    targetName = target.name;
  }

  return new AnalyzedSentence(
      verb, target, targetName, preposition, trailing, session,
      sentence.arguments, sentence.programName);
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

class AnalyzedSentence {
  final ResolvedVerb verb;

  final Target target;

  final String targetName;

  final Preposition preposition;

  final List<String> trailing;

  final UserSession session;

  // TODO(ahe): Remove when compile-and-run is removed.
  final List<String> arguments;

  // TODO(ahe): Remove when compile-and-run is removed.
  final String programName;

  AnalyzedSentence(
      this.verb,
      this.target,
      this.targetName,
      this.preposition,
      this.trailing,
      this.session,
      this.arguments,
      this.programName);

  Future<int> performVerb(VerbContext context) {
    return verb.verb.perform(this, context);
  }
}
