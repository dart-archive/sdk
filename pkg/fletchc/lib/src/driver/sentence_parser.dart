// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.sentence_parser;

import "dart:async" show
  Future;

import "verbs.dart" show
    Verb,
    commonVerbs,
    uncommonVerbs;

import 'dart:convert' show
    JSON;

// TODO(ahe): Remove.
import "driver_commands.dart" show
    Command,
    CommandSender;
import "dart:async" show
  StreamIterator;

// TODO(ahe): Remove.
const String StringOrUri = "String or Uri";

Sentence parseSentence(Iterable<String> arguments) {
  SentenceParser parser = new SentenceParser(arguments);
  return parser.parseSentence();
}

class SentenceParser {
  Words tokens;

  SentenceParser(Iterable<String> tokens)
      : tokens = new Words(tokens);

  Sentence parseSentence() {
    ResolvedVerb verb;
    if (!tokens.isAtEof) {
      verb = parseVerb();
    } else {
      verb = new ResolvedVerb("help", commonVerbs["help"]);
    }
    List<String> rest = <String>[];
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
        null, rest, null, null, null);
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
        new Verb((a, List<String> arguments, b, c, {packageRoot}) {
          print(message);
          return commonVerbs["help"]
              .perform(a, arguments, b, c, packageRoot: packageRoot)
              .then((_) => 1);
        }, null);
  }

  Preposition parsePrepositionOpt() {
    String word = tokens.current;
    switch (word) {
      case "with":
      case "in":
      case "to":
        tokens.consume();
        Target target = tokens.isAtEof ? null : parseTarget();
        return new Preposition(word, target);

      default:
        return null;
    }
  }

  // @private_to.instance
  Target internalParseTarget() {
    String word = tokens.current;
    switch (word) {
      case "session":
      case "class":
      case "method":
      case "file":
        tokens.consume();
        return new NamedTarget(word, parseName());

      case "sessions":
      case "classes":
      case "methods":
      case "files":
        tokens.consume();
        return new Target(word);

      default:
        return new ErrorTarget(
            "Expected 'session(s)', 'class(s)', 'method(s)', or 'file', "
            "but got: ${quoteString(word)}.");
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
  final String word;
  final Target target;

  const Preposition(this.word, this.target);

  String toString() => "Preposition(${quoteString(word)}, $target)";
}

class Target {
  final String noun;

  const Target(this.noun);

  String toString() => "Target(${quoteString(noun)})";
}

class NamedTarget extends Target {
  final String name;

  const NamedTarget(String noun, this.name)
      : super(noun);

  String toString() {
    return "NamedTarget(${quoteString(noun)}, ${quoteString(name)})";
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
  final String fletchVm;

  // TODO(ahe): Get rid of this.
  final List<String> arguments;

  // TODO(ahe): Get rid of this.
  final CommandSender commandSender;

  // TODO(ahe): Get rid of this.
  final StreamIterator<Command> commandIterator;

  // TODO(ahe): Get rid of this.
  @StringOrUri final packageRoot;

  const Sentence(
      this.verb,
      this.preposition,
      this.target,
      this.tailPreposition,
      this.trailing,
      this.fletchVm,
      this.arguments,
      this.commandSender,
      this.commandIterator,
      this.packageRoot);

  Future<int> performVerb() {
    return verb.perform(
        fletchVm, arguments, commandSender, commandIterator,
        packageRoot: packageRoot);
  }

  String toString() => "Sentence($verb, $preposition, $target)";
}
