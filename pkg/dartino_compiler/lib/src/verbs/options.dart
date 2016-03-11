// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.options;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

const bool isBatchMode = const bool.fromEnvironment("dartino-batch-mode");

typedef R ArgumentParser<R>(String argument);

enum OptionKind {
  help,
  verbose,
  version,
  define,
  analyzeOnly,
  fatalIncrementalFailures,
  terminateDebugger,

  /// Not an option
  none,
}

const List<Option> supportedOptions = const <Option>[
  const Option(OptionKind.help, const ['h', '?'], const ['help', 'usage']),
  const Option(OptionKind.verbose, 'v', 'verbose'),
  const Option(OptionKind.version, null, 'version'),
  const Option(OptionKind.analyzeOnly, null, 'analyze-only'),
  const Option(
      OptionKind.fatalIncrementalFailures, null, 'fatal-incremental-failures'),
  const Option(
      OptionKind.terminateDebugger, null, 'terminate-debugger'),
];

final Map<String, Option> shortOptions = computeShortOptions();

final Map<String, Option> longOptions = computeLongOptions();

const String StringOrList =
    "Type of annotation object is either String or List<String>";

class Option {
  final OptionKind kind;

  @StringOrList final shortName;

  @StringOrList final longName;

  final bool requiresArgument;

  final ArgumentParser<dynamic> parseArgument;

  final DiagnosticKind missingArgumentDiagnostic;

  const Option(
      this.kind,
      this.shortName,
      this.longName,
      {this.requiresArgument: false,
       this.parseArgument,
       this.missingArgumentDiagnostic: DiagnosticKind.missingRequiredArgument});

  String toString() {
    return "Option($kind, $shortName, $longName, "
        "requiresArgument: $requiresArgument, "
        "missingArgumentDiagnostic: $missingArgumentDiagnostic)";
  }
}

List<String> parseCommaSeparatedList(String argument) {
  argument = argument.trim();
  if (argument.isEmpty) return <String>[];
  return argument.split(',').map((String e) => e.trim()).toList();
}

Map<String, Option> computeShortOptions() {
  Map<String, Option> result = <String, Option>{};
  for (Option option in supportedOptions) {
    var shortName = option.shortName;
    if (shortName == null) {
      continue;
    } else if (shortName is String) {
      result[shortName] = option;
    } else {
      List<String> shortNames = shortName;
      for (String name in shortNames) {
        result[name] = option;
      }
    }
  }
  return result;
}

Map<String, Option> computeLongOptions() {
  Map<String, Option> result = <String, Option>{};
  for (Option option in supportedOptions) {
    var longName = option.longName;
    if (longName == null) {
      continue;
    } else if (longName is String) {
      result[longName] = option;
    } else {
      List<String> longNames = longName;
      for (String name in longNames) {
        result[name] = option;
      }
    }
  }
  return result;
}

class Options {
  final bool help;
  final bool verbose;
  final bool version;
  final Map<String, String> defines;
  final List<String> nonOptionArguments;
  final bool analyzeOnly;
  final bool fatalIncrementalFailures;
  final bool terminateDebugger;

  Options(
      this.help,
      this.verbose,
      this.version,
      this.defines,
      this.nonOptionArguments,
      this.analyzeOnly,
      this.fatalIncrementalFailures,
      this.terminateDebugger);

  /// Parse [options] which is a list of command-line arguments, such as those
  /// passed to `main`.
  static Options parse(Iterable<String> options) {
    bool help = false;
    bool verbose = false;
    bool version = false;
    Map<String, String> defines = <String, String>{};
    List<String> nonOptionArguments = <String>[];
    bool analyzeOnly = false;
    bool fatalIncrementalFailures = false;
    bool terminateDebugger = isBatchMode;

    Iterator<String> iterator = options.iterator;

    while (iterator.moveNext()) {
      String optionString = iterator.current;
      OptionKind kind;
      var parsedArgument;
      if (optionString.startsWith("-D")) {
        // Define.
        kind = OptionKind.define;
        parsedArgument = optionString.split('=');
        if (parsedArgument.length > 2) {
          throwFatalError(DiagnosticKind.illegalDefine,
                          userInput: optionString,
                          additionalUserInput:
                              parsedArgument.sublist(1).join('='));
        } else if (parsedArgument.length == 1) {
          // If the user does not provide a value, we use `null`.
          parsedArgument.add(null);
        }
      } else if (optionString.startsWith("-")) {
        String name;
        Option option;
        String argument;
        if (optionString.startsWith("--")) {
          // Long option.
          int equalIndex = optionString.indexOf("=", 2);
          if (equalIndex != -1) {
            argument = optionString.substring(equalIndex + 1);
            name = optionString.substring(2, equalIndex);
          } else {
            name = optionString.substring(2);
          }
          option = longOptions[name];
        } else {
          // Short option.
          name = optionString.substring(1);
          option = shortOptions[name];
        }

        if (option == null) {
          throwFatalError(
              DiagnosticKind.unknownOption, userInput: optionString);
        } else if (option.requiresArgument) {
          if (argument == null && iterator.moveNext()) {
            argument = iterator.current;
            if (argument == "=") {
              argument = null;
              if (iterator.moveNext()) {
                argument = iterator.current;
              }
            }
          }
          if (argument == null) {
            // TODO(ahe): Improve error recovery, don't throw.
            throwFatalError(option.missingArgumentDiagnostic, userInput: name);
          }
          parsedArgument = option.parseArgument == null
              ? argument : option.parseArgument(argument);
        } else if (argument != null) {
          assert(!option.requiresArgument);
          // TODO(ahe): Pass what should be removed as additionalUserInput, for
          // example, if saying `--help=fisk`, [userInput] should be `help`,
          // and [additionalUserInput] should be `=fisk`.
          throwFatalError(DiagnosticKind.unexpectedArgument, userInput: name);
        }
        kind = option.kind;
      } else {
        nonOptionArguments.add(optionString);
        kind = OptionKind.none;
      }

      switch (kind) {
        case OptionKind.help:
          help = true;
          break;

        case OptionKind.verbose:
          verbose = true;
          break;

        case OptionKind.version:
          version = true;
          break;

        case OptionKind.define:
          defines[parsedArgument[0]] = parsedArgument[1];
          break;

        case OptionKind.analyzeOnly:
          analyzeOnly = true;
          break;

        case OptionKind.fatalIncrementalFailures:
          fatalIncrementalFailures = true;
          break;

        case OptionKind.terminateDebugger:
          terminateDebugger = true;
          break;

        case OptionKind.none:
          break;
      }
    }

    return new Options(
        help, verbose, version, defines,
        nonOptionArguments, analyzeOnly, fatalIncrementalFailures,
        terminateDebugger);
  }
}
