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
    ErrorTarget,
    NamedTarget,
    Preposition,
    PrepositionKind,
    Sentence,
    Target,
    TargetKind,
    Verb;

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

import '../driver/session_manager.dart' show
    lookupSession; // Don't export this.

import 'actions.dart' show
    Action;

export 'actions.dart' show
    Action;

import 'options.dart' show
    Options;

export 'options.dart' show
    Options;

import 'documentation.dart' show
    helpDocumentation;

import '../guess_configuration.dart' show
    fletchVersion;

void reportErroneousTarget(ErrorTarget target) {
  throwFatalError(target.errorKind, userInput: target.userInput);
}

AnalyzedSentence helpSentence(String message) {
  Future<int> printHelp(_,__) async {
    print(message);
    return 0;
  }
  Action contextHelp = new Action(printHelp, null);
  return new AnalyzedSentence(
      new Verb("?", contextHelp), null, null, null, null, null, null,
      null, null, null);
}

AnalyzedSentence analyzeSentence(Sentence sentence, Options options) {
  // Check the sentence's version matches the persistent process' version.
  if (sentence.version != null && sentence.version != fletchVersion) {
    throwFatalError(
        DiagnosticKind.compilerVersionMismatch,
        userInput: fletchVersion,
        additionalUserInput: sentence.version);
  }
  if (options != null && options.version) {
    return helpSentence(fletchVersion);
  }
  if (sentence.verb.isErroneous) {
    sentence.verb.action.perform(null, null);
  }
  sentence.targets.where((Target t) => t.isErroneous)
      .forEach(reportErroneousTarget);
  sentence.prepositions.map((p) => p.target).where((Target t) => t.isErroneous)
      .forEach(reportErroneousTarget);

  Uri base = Uri.base;
  if (sentence.currentDirectory != null) {
    base = fileUri(appendSlash(sentence.currentDirectory), base);
  }
  Verb verb = sentence.verb;
  Action action = verb.action;
  List<String> trailing = sentence.trailing;

  for (Target target in sentence.targets) {
    if (target.kind == TargetKind.HELP) {
      return helpSentence(action.documentation);
    }
  }

  NamedTarget inSession;
  Uri toUri;
  Uri withUri;

  /// Validates a preposition of kind `in`. For now, the only possible legal
  /// target is of kind `session`. Store such as session in [inSession].
  void checkInTarget(Preposition preposition) {
    assert(preposition.kind == PrepositionKind.IN);
    if (preposition.target.kind == TargetKind.SESSION) {
      if (inSession != null) {
        throwFatalError(
            DiagnosticKind.duplicatedIn, preposition: preposition);
      }
      inSession = preposition.target;
      if (!action.requiresSession) {
        throwFatalError(
            DiagnosticKind.verbRequiresNoSession,
            verb: verb, sessionName: inSession.name);
      }
    } else {
      throwFatalError(
          DiagnosticKind.cantPerformVerbIn,
          verb: verb, target: preposition.target);
    }
  }

  /// Validates a preposition of kind `to`. For now, the only possible legal
  /// target is of kind `file`. Store such a file in [toUri].
  void checkToTarget(Preposition preposition) {
    assert(preposition.kind == PrepositionKind.TO);
    if (preposition.target.kind == TargetKind.FILE) {
      if (toUri != null) {
        throwFatalError(
            DiagnosticKind.duplicatedTo, preposition: preposition);
      }
      NamedTarget target = preposition.target;
      toUri = fileUri(target.name, base);
      if (!action.requiresToUri) {
        throwFatalError(
            DiagnosticKind.verbRequiresNoToFile,
            verb: verb, userInput: target.name);
      }
    } else {
      throwFatalError(
          DiagnosticKind.cantPerformVerbTo,
          verb: verb, target: preposition.target);
    }
  }

  /// Validates a preposition of kind `with`. For now, the only possible legal
  /// target is of kind `file`. Store such a file in [withUri].
  void checkWithTarget(Preposition preposition) {
    assert(preposition.kind == PrepositionKind.WITH);
    if (preposition.target.kind == TargetKind.FILE) {
      if (withUri != null) {
        throwFatalError(
            DiagnosticKind.duplicatedWith, preposition: preposition);
      }
      NamedTarget target = preposition.target;
      withUri = fileUri(target.name, base);
      if (!action.supportsWithUri) {
        throwFatalError(
            DiagnosticKind.verbRequiresNoWithFile,
            verb: verb, userInput: target.name);
      }
    } else {
      throwFatalError(
          DiagnosticKind.cantPerformVerbWith,
          verb: verb, target: preposition.target);
    }
  }

  Target target;
  Target secondaryTarget;
  Iterator<Target> targets = sentence.targets.iterator;
  if (targets.moveNext()) {
    target = targets.current;
  }
  if (targets.moveNext()) {
    secondaryTarget = targets.current;
  }
  while (targets.moveNext()) {
    throwFatalError(
        DiagnosticKind.verbDoesNotSupportTarget, verb: verb, target: target);
  }
  if (secondaryTarget != null) {
    if (secondaryTarget.kind == TargetKind.FILE) {
      if (action.requiresToUri) {
        NamedTarget target = secondaryTarget;
        toUri = fileUri(target.name, base);
      } else {
        throwFatalError(
            DiagnosticKind.verbRequiresNoToFile,
            verb: verb, target: secondaryTarget);
      }
    } else {
      throwFatalError(
          DiagnosticKind.cantPerformVerbTo,
          verb: verb, target: secondaryTarget);
    }
  }

  for (Preposition preposition in sentence.prepositions) {
    switch (preposition.kind) {
      case PrepositionKind.IN:
        checkInTarget(preposition);
        break;

      case PrepositionKind.TO:
        checkToTarget(preposition);
        break;

      case PrepositionKind.WITH:
        checkWithTarget(preposition);
        break;
    }
  }

  if (action.requiresToUri && toUri == null) {
    throwFatalError(DiagnosticKind.missingToFile);
  }

  if (!action.allowsTrailing) {
    if (trailing != null) {
      throwFatalError(
          DiagnosticKind.extraArguments, userInput: trailing.join(' '));
    }
  }

  if (target != null &&
      action.requiredTarget == null &&
      action.supportedTargets == null) {
    throwFatalError(
        DiagnosticKind.verbDoesntSupportTarget, verb: verb, target: target);
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
            throwFatalError(
                DiagnosticKind.verbRequiresTarget, verb: verb,
                requiredTarget: action.requiredTarget);
          }
          break;
      }
    } else if (target.kind != action.requiredTarget) {
      switch (action.requiredTarget) {
        case TargetKind.TCP_SOCKET:
          throwFatalError(
              DiagnosticKind.verbRequiresSocketTarget,
              verb: verb, target: target);
          break;

        case TargetKind.FILE:
          throwFatalError(
              DiagnosticKind.verbRequiresFileTarget,
              verb: verb, target: target);
          break;

        default:
          throwFatalError(
              DiagnosticKind.verbRequiresTargetButGot,
              verb: verb, target: target,
              requiredTarget: action.requiredTarget);
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
  if (inSession != null) {
    sessionName = inSession.name;
    if (sessionName == null) {
      throwFatalError(DiagnosticKind.missingSessionName);
    }
  } else if (action.requiresSession) {
    sessionName = currentSession;
  } else if (action.requiresTargetSession &&
      target is NamedTarget &&
      target.name == null) {
    throwFatalError(DiagnosticKind.missingSessionName);
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
      verb, target, targetName, trailing, sessionName, base, programName,
      targetUri, toUri, withUri);
}

Uri fileUri(String path, Uri base) => base.resolveUri(new Uri.file(path));

abstract class VerbContext {
  final ClientController client;

  final IsolatePool pool;

  final UserSession session;

  VerbContext(this.client, this.pool, this.session);

  Future<int> performTaskInWorker(SharedTask task);

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

  final List<String> trailing;

  final String sessionName;

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
      this.trailing,
      this.sessionName,
      this.base,
      this.programName,
      this.targetUri,
      this.toTargetUri,
      this.withUri);

  Future<int> performVerb(VerbContext context) {
    return verb.action.perform(this, context);
  }
}
