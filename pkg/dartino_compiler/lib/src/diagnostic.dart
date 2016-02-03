// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.diagnostic;

import 'messages.dart' show
    DiagnosticKind,
    getMessage;

import 'hub/sentence_parser.dart' show
    Preposition,
    Target,
    TargetKind,
    Verb;

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

  static const DiagnosticParameter requiredTarget = const DiagnosticParameter(
      DiagnosticParameterType.targetKind, 'requiredTarget');

  static const DiagnosticParameter userInput = const DiagnosticParameter(
      DiagnosticParameterType.string, 'userInput');

  static const DiagnosticParameter additionalUserInput =
      const DiagnosticParameter(
          DiagnosticParameterType.string, 'additionalUserInput');

  static const DiagnosticParameter address = const DiagnosticParameter(
      DiagnosticParameterType.string, 'address');

  static const DiagnosticParameter preposition = const DiagnosticParameter(
      DiagnosticParameterType.preposition, 'preposition');

  // TODO(ahe): This should probably be a more generalized location, for
  // example, Spannable from dart2js.
  static const DiagnosticParameter uri = const DiagnosticParameter(
      DiagnosticParameterType.uri, 'uri');

  static const DiagnosticParameter fixit = const DiagnosticParameter(
      DiagnosticParameterType.string, 'fixit');
}

enum DiagnosticParameterType {
  string,
  verb,
  sessionName,
  target,
  targetKind,
  preposition,
  uri,
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
    String formattedMessage = template;
    Set<String> suppliedParameters = new Set<String>();
    arguments.forEach((DiagnosticParameter parameter, value) {
      suppliedParameters.add('$parameter');
      String stringValue;
      switch (parameter.type) {
        case DiagnosticParameterType.string:
          stringValue = value;
          break;

        case DiagnosticParameterType.uri:
          stringValue = '$value';
          break;

        case DiagnosticParameterType.verb:
          Verb verb = value;
          stringValue = verb.name;
          break;

        case DiagnosticParameterType.sessionName:
          stringValue = value;
          break;

        case DiagnosticParameterType.target:
          Target target = value;
          // TODO(karlklose): Improve this conversion.
          stringValue = '$target';
          break;

        case DiagnosticParameterType.targetKind:
          TargetKind kind = value;
          // TODO(karlklose): Improve this conversion.
          stringValue = '$kind';
          break;

        case DiagnosticParameterType.preposition:
          Preposition preposition = value;
          // TODO(karlklose): Improve this conversion.
          stringValue =
              preposition.kind.toString().split('.').last.toLowerCase();
          break;

        default:
          throwInternalError("""
Unsupported parameter type '${parameter.type}'
found for parameter '$parameter'
when trying to format the following error message:

$formattedMessage""");
          break;
      }
      formattedMessage = formattedMessage.replaceAll('$parameter', stringValue);
    });

    Set<String> usedParameters = new Set<String>();
    for (Match match in new RegExp("#{[^}]*}").allMatches(template)) {
      String parameter = match.group(0);
      usedParameters.add(parameter);
    }

    Set<String> unusedParameters =
        suppliedParameters.difference(usedParameters);
    Set<String> missingParameters =
        usedParameters.difference(suppliedParameters);

    if (missingParameters.isNotEmpty || unusedParameters.isNotEmpty) {
      throw """
Error when formatting diagnostic:
  kind: $kind
  template: $template
  arguments: $arguments
  missingParameters: ${missingParameters.join(', ')}
  unusedParameters: ${unusedParameters.join(', ')}
  formattedMessage: $formattedMessage""";
    }

    return formattedMessage;
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

/// Throw an internal error that will be recorded as a compiler crash.
///
/// In general, assume, no matter how unlikely, that [message] may be read by a
/// user (that is, a developer using Dartino). For this reason, try to:
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
     Verb verb,
     String sessionName,
     Target target,
     TargetKind requiredTarget,
     String address,
     String userInput,
     String additionalUserInput,
     Preposition preposition,
     Uri uri,
     String fixit}) {
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
  if (additionalUserInput != null) {
    arguments[DiagnosticParameter.additionalUserInput] = additionalUserInput;
  }
  if (preposition != null) {
    arguments[DiagnosticParameter.preposition] = preposition;
  }
  if (uri != null) {
    arguments[DiagnosticParameter.uri] = uri;
  }
  if (requiredTarget != null) {
    arguments[DiagnosticParameter.requiredTarget] = requiredTarget;
  }
  if (fixit != null) {
    arguments[DiagnosticParameter.fixit] = fixit;
  }
  throw new InputError(kind, arguments);
}
