// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.diagnostic;

import 'messages.dart' show
    DiagnosticKind,
    getMessage;

import 'package:compiler/src/dart2jslib.dart' show
    MessageKind;

import 'driver/sentence_parser.dart' show
    ResolvedVerb,
    Target;

export 'messages.dart' show
    DiagnosticKind;

/// Represents a parameter to a diagnostic, that is, a key in the `arguments`
/// map of [Diagnostic]. In a diagnostic message template (a [String]), a
/// parameter is represented by `"#{name}"`.
class DiagnosticParameter {
  final DiagnosticParameterType type;

  final String name;

  const DiagnosticParameter(this.type, this.name);

  String toString() => '#{$name}';

  static const DiagnosticParameter message = const DiagnosticParameter(
      DiagnosticParameterType.string, 'message');

  static const DiagnosticParameter verb = const DiagnosticParameter(
      DiagnosticParameterType.verb, 'verb');

  static const DiagnosticParameter sessionName = const DiagnosticParameter(
      DiagnosticParameterType.sessionName, 'sessionName');

  static const DiagnosticParameter target = const DiagnosticParameter(
      DiagnosticParameterType.target, 'target');

  static const DiagnosticParameter userInput = const DiagnosticParameter(
      DiagnosticParameterType.string, 'userInput');

  static const DiagnosticParameter address = const DiagnosticParameter(
      DiagnosticParameterType.string, 'address');
}

enum DiagnosticParameterType {
  string,
  verb,
  sessionName,
  target,
}

class Diagnostic {
  final DiagnosticKind kind;

  final String template;

  final Map<DiagnosticParameter, dynamic> arguments;

  const Diagnostic(this.kind, this.template, this.arguments);

  String toString() => 'Diagnostic($kind, $template, $arguments)';

  /// Convert [template] to a human-readable message. This entails replacing
  /// all occurences of `"#{parameterName}"` with the corresponding value in
  /// [arguments].
  String formatMessage() {
    return new MessageKind(template)
        .message(toDart2jsArguments(arguments), false)
        .computeMessage();
  }
}

class InputError {
  final DiagnosticKind kind;

  final Map<DiagnosticParameter, dynamic> arguments;

  const InputError(this.kind, [this.arguments]);

  Diagnostic asDiagnostic() {
    return new Diagnostic(kind, getMessage(kind), arguments);
  }

  String toString() => 'InputError($kind, $arguments)';
}

/// Converts an argument map with [DiagnosticParameter] keys and their
/// corresponding values to a map that can be processed by dart2js'
/// `Message.computeMessage` (see package:compiler/src/warnings.dart).
Map<String, String> toDart2jsArguments(
    Map<DiagnosticParameter, dynamic> arguments) {
  Map<String, String> result = <String, String>{};
  arguments.forEach((DiagnosticParameter parameter, value) {
    String stringValue;
    switch (parameter.type) {
      case DiagnosticParameterType.string:
        stringValue = value;
        break;

      case DiagnosticParameterType.verb:
        ResolvedVerb verb = value;
        stringValue = verb.name;
        break;

      case DiagnosticParameterType.sessionName:
        stringValue = value;
        break;

      case DiagnosticParameterType.target:
        Target target = value;
        // TODO(ahe): Improve this conversion.
        stringValue = target.toString();
        break;
    }
    result[parameter.name] = stringValue;
  });
  return result;
}

/// Throw an internal error that will be recorded as a compiler crash.
///
/// In general, assume, no matter how unlikely, that [message] may be read by a
/// user (that is, a developer using Fletch). For this reason, try to:
///
/// * Avoid phrases that can be interpreted as blaming the user (all error
///   messages should state what is wrong, in a way that doesn't assign blame).
///
/// * Avoid being cute or funny (there's nothing more frustrating than being
///   affected by a bug and see a cute or funny message, especially if it
///   happens a lot).
///
/// * Avoid phrases like "unreachable", "can't happen", "shouldn't happen",
///   "shouldn't be called", simply because it is wrong: it did happen. In most
///   cases a factual message would be "unimplemented", "unhandled case",
///   etc. Remember that the stacktrace will pinpoint the exact location of the
///   problem, so no need to repeat a method name.
void throwInternalError(String message) {
  throw new InputError(
      DiagnosticKind.internalError,
      <DiagnosticParameter, dynamic>{DiagnosticParameter.message: message});
}

void throwFatalError(
    DiagnosticKind kind,
    {String message,
     ResolvedVerb verb,
     String sessionName,
     Target target,
     String address,
     String userInput}) {
  Map<DiagnosticParameter, dynamic> arguments =
      <DiagnosticParameter, dynamic>{};
  if (message != null) {
    arguments[DiagnosticParameter.message] = message;
  }
  if (verb != null) {
    arguments[DiagnosticParameter.verb] = verb;
  }
  if (sessionName != null) {
    arguments[DiagnosticParameter.sessionName] = sessionName;
  }
  if (target != null) {
    arguments[DiagnosticParameter.target] = target;
  }
  if (address != null) {
    arguments[DiagnosticParameter.address] = address;
  }
  if (userInput != null) {
    arguments[DiagnosticParameter.userInput] = userInput;
  }
  throw new InputError(kind, arguments);
}
