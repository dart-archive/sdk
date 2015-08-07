// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.sentence_parser;

import 'dart:convert' show
    JSON;

import '../verbs/verbs.dart' show
    Verb,
    commonVerbs,
    uncommonVerbs;

import '../verbs/infrastructure.dart' show
    AnalyzedSentence;

Sentence parseSentence(
    Iterable<String> arguments,
    {bool includesProgramName}) {
  SentenceParser parser =
      new SentenceParser(arguments, includesProgramName == true);
  return parser.parseSentence();
}

class SentenceParser {
  final String programName;
  Words tokens;

  SentenceParser(Iterable<String> tokens, bool includesProgramName)
      : programName = includesProgramName ? tokens.first : null,
        tokens = new Words(tokens.skip(includesProgramName ? 1 : 0));

  Sentence parseSentence() {
    ResolvedVerb verb;
    if (!tokens.isAtEof) {
      verb = parseVerb();
    } else {
      verb = new ResolvedVerb("help", commonVerbs["help"]);
    }
    Preposition preposition = parsePrepositionOpt();
    Target target = parseTargetOpt();
    Preposition tailPreposition = parsePrepositionOpt();
    List<String> trailing = <String>[];
    while (!tokens.isAtEof) {
      trailing.add(tokens.current);
      tokens.consume();
    }
    if (trailing.isEmpty) {
      trailing = null;
    }
    return new Sentence(
        verb, preposition, target, tailPreposition, trailing,
        programName,
        // TODO(ahe): Get rid of the following argument:
        tokens.originalInput.skip(1).toList());
  }

  ResolvedVerb parseVerb() {
    String name = tokens.current;
    Verb verb = commonVerbs[name];
    if (verb != null) {
      tokens.consume();
      return new ResolvedVerb(name, verb);
    }
    verb = uncommonVerbs[name];
    if (verb != null) {
      tokens.consume();
      return new ResolvedVerb(name, verb);
    }
    return new ResolvedVerb(name, makeErrorVerb("Unknown argument: $name"));
  }

  Verb makeErrorVerb(String message) {
    return
        new Verb((AnalyzedSentence sentence, context) {
          print(message);
          return commonVerbs["help"].perform(sentence, context)
              .then((_) => 1);
        }, null);
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

      default:
        return new ErrorTarget(
            "Expected 'session(s)', 'class(s)', 'method(s)', 'file(s)', "
            "or 'all', but got: ${quoteString(word)}.");
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

class ResolvedVerb {
  final String name;
  final Verb verb;

  const ResolvedVerb(this.name, this.verb);

  String toString() => "ResolvedVerb(${quoteString(name)})";
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
  final String message;

  const ErrorTarget(this.message)
      : super(null);

  String toString() => "ErrorTarget(${quoteString(message)})";
}

/// A sentence is a written command to fletch. Normally, this command is
/// written on the command-line and should be easy to write without having
/// getting into conflict with Unix shell command line parsing.
///
/// An example sentence is:
///   `create class MyClass in session MySession`
///
/// In this example, `create` is a [Verb], `class MyClass` is a [Target], and
/// `in session MySession` is a [Preposition] in tail position.
class Sentence {
  /// For example, `create`.
  final ResolvedVerb verb;

  /// For example, `in session MySession`
  final Preposition preposition;

  /// For example, `class MyClass`
  final Target target;

  /// For example, `in session MySession`
  final Preposition tailPreposition;

  /// Any tokens found after this sentence.
  final List<String> trailing;

  // TODO(ahe): Get rid of this.
  final String programName;

  // TODO(ahe): Get rid of this.
  final List<String> arguments;

  const Sentence(
      this.verb,
      this.preposition,
      this.target,
      this.tailPreposition,
      this.trailing,
      this.programName,
      this.arguments);

  String toString() => "Sentence($verb, $preposition, $target)";
}
