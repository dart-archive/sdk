// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.sentence_parser;

import 'dart:convert' show
    JSON;

import '../verbs/actions.dart' show
    Action,
    commonActions,
    uncommonActions;

import '../verbs/infrastructure.dart' show
    AnalyzedSentence,
    DiagnosticKind,
    throwFatalError;

Sentence parseSentence(
    Iterable<String> arguments,
    {bool includesProgramName}) {
  SentenceParser parser =
      new SentenceParser(arguments, includesProgramName == true);
  return parser.parseSentence();
}

class SentenceParser {
  final String programName;
  final String shortProgramName;
  final String currentDirectory;
  Words tokens;

  SentenceParser(Iterable<String> tokens, bool includesProgramName)
      : currentDirectory = includesProgramName ? tokens.first : null,
        programName = includesProgramName ? tokens.skip(1).first : null,
        shortProgramName = includesProgramName ? tokens.skip(2).first : null,
        tokens = new Words(tokens.skip(includesProgramName ? 3 : 0));

  Sentence parseSentence() {
    Verb verb;
    if (!tokens.isAtEof) {
      verb = parseVerb();
    } else {
      verb = new Verb("help", commonActions["help"]);
    }
    List<Preposition> prepositions = <Preposition>[];
    List<Target> targets = <Target>[];
    while (!tokens.isAtEof) {
      Preposition preposition = parsePrepositionOpt();
      if (preposition != null) {
        prepositions.add(preposition);
        continue;
      }
      Target target = parseTargetOpt();
      if (target != null) {
        targets.add(target);
        continue;
      }
      break;
    }
    List<String> trailing = <String>[];
    while (!tokens.isAtEof) {
      trailing.add(tokens.current);
      tokens.consume();
    }
    if (trailing.isEmpty) {
      trailing = null;
    }
    return new Sentence(
        verb, prepositions, targets, trailing,
        currentDirectory, programName,
        // TODO(ahe): Get rid of the following argument:
        tokens.originalInput.skip(1).toList());
  }

  Verb parseVerb() {
    String name = tokens.current;
    Action action = commonActions[name];
    if (action != null) {
      tokens.consume();
      return new Verb(name, action);
    }
    action = uncommonActions[name];
    if (action != null) {
      tokens.consume();
      return new Verb(name, action);
    }
    return new ErrorVerb(name);
  }

  Preposition parsePrepositionOpt() {
    // TODO(ahe): toLowerCase()?
    String word = tokens.current;
    Preposition makePreposition(PrepositionKind kind) {
      tokens.consume();
      Target target = tokens.isAtEof ? null : parseTarget();
      return new Preposition(kind, target);
    }
    switch (word) {
      case "with":
        return makePreposition(PrepositionKind.WITH);

      case "in":
        return makePreposition(PrepositionKind.IN);

      case "to":
        return makePreposition(PrepositionKind.TO);


      default:
        return null;
    }
  }

  // @private_to.instance
  Target internalParseTarget() {
    // TODO(ahe): toLowerCase()?
    String word = tokens.current;

    NamedTarget makeNamedTarget(TargetKind kind) {
      tokens.consume();
      return new NamedTarget(kind, parseName());
    }

    Target makeTarget(TargetKind kind) {
      tokens.consume();
      return new Target(kind);
    }

    if (looksLikeAUri(word)) {
      return new NamedTarget(TargetKind.FILE, parseName());
    }

    switch (word) {
      case "session":
        return makeNamedTarget(TargetKind.SESSION);

      case "class":
        return makeNamedTarget(TargetKind.CLASS);

      case "method":
        return makeNamedTarget(TargetKind.METHOD);

      case "file":
        return makeNamedTarget(TargetKind.FILE);

      case "tcp_socket":
        return makeNamedTarget(TargetKind.TCP_SOCKET);

      case "sessions":
        return makeTarget(TargetKind.SESSIONS);

      case "classes":
        return makeTarget(TargetKind.CLASSES);

      case "methods":
        return makeTarget(TargetKind.METHODS);

      case "files":
        return makeTarget(TargetKind.FILES);

      case "all":
        return makeTarget(TargetKind.ALL);

      case "run-to-main":
        return makeTarget(TargetKind.RUN_TO_MAIN);

      case "backtrace":
        return makeTarget(TargetKind.BACKTRACE);

      case "continue":
        return makeTarget(TargetKind.CONTINUE);

      case "break":
        return makeNamedTarget(TargetKind.BREAK);

      case "list":
        return makeTarget(TargetKind.LIST);

      case "disasm":
        return makeTarget(TargetKind.DISASM);

      case "frame":
        return makeNamedTarget(TargetKind.FRAME);

      case "delete-breakpoint":
        return makeNamedTarget(TargetKind.DELETE_BREAKPOINT);

      case "list-breakpoints":
        return makeTarget(TargetKind.LIST_BREAKPOINTS);

      case "step":
        return makeTarget(TargetKind.STEP);

      case "step-over":
        return makeTarget(TargetKind.STEP_OVER);

      case "fibers":
        return makeTarget(TargetKind.FIBERS);

      case "finish":
        return makeTarget(TargetKind.FINISH);

      case "restart":
        return makeTarget(TargetKind.RESTART);

      case "step-bytecode":
        return makeTarget(TargetKind.STEP_BYTECODE);

      case "step-over-bytecode":
        return makeTarget(TargetKind.STEP_OVER_BYTECODE);

      case "print":
        return makeNamedTarget(TargetKind.PRINT);

      case "print-all":
        return makeTarget(TargetKind.PRINT_ALL);

      case "toggle":
        return makeNamedTarget(TargetKind.TOGGLE);

      case "help":
        return makeTarget(TargetKind.HELP);

      default:
        return new ErrorTarget(DiagnosticKind.expectedTargetButGot, word);
    }
  }

  Target parseTargetOpt() {
    Target target = internalParseTarget();
    return target is ErrorTarget ? null :  target;
  }

  Target parseTarget() {
    Target target = internalParseTarget();
    if (target is ErrorTarget) {
      tokens.consume();
    }
    return target;
  }

  String parseName() {
    // TODO(ahe): Rename this method? It doesn't necessarily parse a name, just
    // whatever is the next word.
    String name = tokens.current;
    tokens.consume();
    return name;
  }

  /// Returns true if [word] looks like it is a (relative) URI.
  bool looksLikeAUri(String word) {
    return
        word != null &&
        !word.startsWith("-") &&
        word.contains(".");
  }
}

String quoteString(String string) => JSON.encode(string);

class Words {
  final Iterable<String> originalInput;

  final Iterator<String> iterator;

  // @private_to.instance
  bool internalIsAtEof;

  // @private_to.instance
  int internalPosition = 0;

  Words(Iterable<String> input)
      : this.internal(input, input.iterator);

  Words.internal(this.originalInput, Iterator<String> iterator)
      : iterator = iterator,
        internalIsAtEof = !iterator.moveNext();

  bool get isAtEof => internalIsAtEof;

  int get position => internalPosition;

  String get current => iterator.current;

  void consume() {
    internalIsAtEof = !iterator.moveNext();
    if (!isAtEof) {
      internalPosition++;
    }
  }
}

class Verb {
  final String name;
  final Action action;

  const Verb(this.name, this.action);

  bool get isErroneous => false;

  String toString() => "Verb(${quoteString(name)})";
}

class ErrorVerb implements Verb {
  final String name;

  const ErrorVerb(this.name);

  bool get isErroneous => true;

  Action get action {
    throwFatalError(DiagnosticKind.unknownAction, userInput: name);
  }
}

class Preposition {
  final PrepositionKind kind;
  final Target target;

  const Preposition(this.kind, this.target);

  String toString() => "Preposition($kind, $target)";
}

enum PrepositionKind {
  WITH,
  IN,
  TO,
}

class Target {
  final TargetKind kind;

  const Target(this.kind);

  bool get isErroneous => false;

  String toString() => "Target($kind)";
}

enum TargetKind {
  SESSION,
  CLASS,
  METHOD,
  FILE,
  TCP_SOCKET,
  SESSIONS,
  CLASSES,
  METHODS,
  FILES,
  ALL,
  RUN_TO_MAIN,
  BACKTRACE,
  CONTINUE,
  BREAK,
  LIST,
  DISASM,
  FRAME,
  DELETE_BREAKPOINT,
  LIST_BREAKPOINTS,
  STEP,
  STEP_OVER,
  FIBERS,
  FINISH,
  RESTART,
  STEP_BYTECODE,
  STEP_OVER_BYTECODE,
  PRINT,
  PRINT_ALL,
  TOGGLE,
  HELP,
}

class NamedTarget extends Target {
  final String name;

  const NamedTarget(TargetKind kind, this.name)
      : super(kind);

  String toString() {
    return "NamedTarget($kind, ${quoteString(name)})";
  }
}

class ErrorTarget extends Target {
  final DiagnosticKind errorKind;
  final String userInput;

  const ErrorTarget(this.errorKind, this.userInput)
      : super(null);

  bool get isErroneous => true;

  String toString() => "ErrorTarget($errorKind, ${quoteString(userInput)})";
}

/// A sentence is a written command to fletch. Normally, this command is
/// written on the command-line and should be easy to write without having
/// getting into conflict with Unix shell command line parsing.
///
/// An example sentence is:
///   `create class MyClass in session MySession`
///
/// In this example, `create` is a [Verb], `class MyClass` is a [Target], and
/// `in session MySession` is a [Preposition].
class Sentence {
  /// For example, `create`.
  final Verb verb;

  /// For example, `in session MySession`
  final List<Preposition> prepositions;

  /// For example, `class MyClass`
  final List<Target> targets;

  /// Any tokens found after this sentence.
  final List<String> trailing;

  /// The current directory of the C++ client.
  final String currentDirectory;

  // TODO(ahe): Get rid of this.
  final String programName;

  // TODO(ahe): Get rid of this.
  final List<String> arguments;

  const Sentence(
      this.verb,
      this.prepositions,
      this.targets,
      this.trailing,
      this.currentDirectory,
      this.programName,
      this.arguments);

  String toString() => "Sentence($verb, $prepositions, $targets)";
}
