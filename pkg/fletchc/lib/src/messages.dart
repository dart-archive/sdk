// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.messages;

import 'diagnostic.dart' show
    Diagnostic, // For documentation only.
    DiagnosticParameter;

enum DiagnosticKind {
  expectedAPortNumber,
  expectedFileTarget,
  expectedToPreposition,
  internalError,
  missingToFile,
  noFileTarget,
  noSuchSession,
  noTcpSocketTarget,
  sessionAlreadyExists,
  settingsCompileTimeConstantAsOption,
  settingsConstantsNotAMap,
  settingsNotAMap,
  settingsNotJson,
  settingsOptionNotAString,
  settingsOptionsNotAList,
  settingsPackagesNotAString,
  settingsUnrecognizedConstantValue,
  settingsUnrecognizedKey,
  socketConnectError,
  verbDoesNotSupportTarget,
  verbRequiresFileTarget,
  verbRequiresNoSession,
  verbRequiresSessionTarget,
  verbRequiresSocketTarget,

  // TODO(ahe): Remove when compile_and_run_verb.dart is removed.
  unknownOption,

  // TODO(ahe): Remove when compile_and_run_verb.dart is removed.
  missingRequiredArgument,

  // TODO(ahe): Remove when debug attach implicitly.
  attachToVmBeforeRun,

  // TODO(ahe): Remove when debug compile implicitly.
  compileBeforeRun,
}

/// Returns the diagnostic message template for [kind]. A diagnostic message
/// should contain three pieces of information:
///
///   1. What is wrong?
///   2. Why is it wrong?
///   3. How do you fix it?
///
/// In addition, make sure to get a review from a UX expert before adding new
/// diagnostics, or when updating existing diagnostics.
///
/// A diagnostic message template is a string which includes special markers
/// (`"#{parameterName}"`). To produce a human-readable error message, one can
/// use [Diagnostic.formatMessage].
String getMessage(DiagnosticKind kind) {
  // Implementation note: Instead of directly writing `"#{parameterName}"` in
  // templates, use DiagnosticParameter to help reduce the chance of typos, and
  // to ensure all diagnostics can be processed by a third-party.

  const DiagnosticParameter message = DiagnosticParameter.message;
  const DiagnosticParameter verb = DiagnosticParameter.verb;
  const DiagnosticParameter sessionName = DiagnosticParameter.sessionName;
  const DiagnosticParameter target = DiagnosticParameter.target;
  const DiagnosticParameter userInput = DiagnosticParameter.userInput;
  const DiagnosticParameter additionalUserInput =
      DiagnosticParameter.additionalUserInput;
  const DiagnosticParameter address = DiagnosticParameter.address;
  const DiagnosticParameter preposition = DiagnosticParameter.preposition;
  const DiagnosticParameter uri = DiagnosticParameter.uri;

  switch (kind) {
    case DiagnosticKind.internalError:
      return "Internal error: $message";

    case DiagnosticKind.verbRequiresNoSession:
      return "Can't perform '$verb' in a session. "
          "Try removing 'in session $sessionName'";

    case DiagnosticKind.verbRequiresSessionTarget:
      return "Can't perform '$verb' without a session "
          "target. Try adding 'session <SESSION_NAME>' to the commmand line";

    case DiagnosticKind.verbRequiresFileTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '$verb' without a file, but got '$target'";

    case DiagnosticKind.verbRequiresSocketTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '$verb' without a socket, but got '$target'";

    case DiagnosticKind.verbDoesNotSupportTarget:
      return "'$verb' can't be performed on '$target'";

    case DiagnosticKind.noSuchSession:
      return "Couldn't find a session called '$sessionName'. "
          "Try running 'fletch create session $sessionName'";

    case DiagnosticKind.sessionAlreadyExists:
      return "Couldn't create session named '$sessionName'; "
          "A session called $sessionName already exists.";

    case DiagnosticKind.noFileTarget:
      return "No file provided. Try adding <FILE_NAME> to the command line";

    case DiagnosticKind.noTcpSocketTarget:
      return "No TCP socket provided. "
          "Try adding 'tcp_socket HOST:PORT' to the command line";

    case DiagnosticKind.expectedAPortNumber:
      return "Expected a port number, but got '$userInput'";

    case DiagnosticKind.socketConnectError:
      return "Unable to establish connection to $address: $message";

    case DiagnosticKind.attachToVmBeforeRun:
      return "Unable to run program without being attached to a VM. "
          "Try running 'fletch attach'";

    case DiagnosticKind.compileBeforeRun:
      return "No program to run. Try running 'fletch compile'";

    case DiagnosticKind.missingToFile:
      return "No destination file provided. "
          "Try adding 'to <FILE_NAME>' to the command line";

    case DiagnosticKind.expectedToPreposition:
      // TODO(lukechurch): Review UX.
      return "Expected 'to' but got '$preposition'";

    case DiagnosticKind.expectedFileTarget:
      // TODO(lukechurch): Review UX.
      return "Expected a file but got '$target'";

    case DiagnosticKind.unknownOption:
      return "Unknown option: '$userInput'";

    case DiagnosticKind.missingRequiredArgument:
      return "Error in option: $message";

    case DiagnosticKind.settingsNotAMap:
      return "$uri: isn't a map";

    case DiagnosticKind.settingsNotJson:
      return "$uri: unable to decode as JSON: $message";

    case DiagnosticKind.settingsPackagesNotAString:
      return "$uri: 'packages' value isn't a String";

    case DiagnosticKind.settingsOptionsNotAList:
      return "$uri: 'options' value isn't a List";

    case DiagnosticKind.settingsOptionNotAString:
      return "$uri: found 'options' entry '$userInput' which isn't a String";

    case DiagnosticKind.settingsCompileTimeConstantAsOption:
      return "$uri: compile-time constants should be in "
          "the 'constants' map, not in 'options': '$userInput'";

    case DiagnosticKind.settingsConstantsNotAMap:
      return "$uri: 'constants' value isn't a Map";

    case DiagnosticKind.settingsUnrecognizedConstantValue:
      return "$uri: found 'constant[$userInput]' value '$additionalUserInput' "
          "isn't a bool, int, or String";

    case DiagnosticKind.settingsUnrecognizedKey:
      return "$uri: unexpected key '$userInput'";
  }
}
