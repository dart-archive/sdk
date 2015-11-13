// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.messages;

import 'diagnostic.dart' show
    Diagnostic, // For documentation only.
    DiagnosticParameter;

enum DiagnosticKind {
  agentVersionMismatch,
  busySession,
  cantPerformVerbIn,
  cantPerformVerbTo,
  cantPerformVerbWith,
  compilerVersionMismatch,
  duplicatedIn,
  duplicatedTo,
  duplicatedWith,
  expectedAPortNumber,
  expectedTargetButGot,
  extraArguments,
  handShakeFailed,
  internalError,
  missingRequiredArgument,
  missingToFile,
  missingSessionName,
  noFileTarget,
  noSuchSession,
  noTcpSocketTarget,
  quitTakesNoArguments,
  sessionAlreadyExists,
  settingsCompileTimeConstantAsOption,
  settingsConstantsNotAMap,
  settingsDeviceAddressNotAString,
  settingsNotAMap,
  settingsNotJson,
  settingsOptionNotAString,
  settingsDeviceTypeNotAString,
  settingsDeviceTypeUnrecognized,
  settingsOptionsNotAList,
  settingsPackagesNotAString,
  settingsUnrecognizedConstantValue,
  settingsUnrecognizedKey,
  noAgentFound,
  upgradeInvalidPackageName,
  socketAgentConnectError,
  socketAgentReplyError,
  socketVmConnectError,
  socketVmReplyError,
  terminatedSession,
  unexpectedArgument,
  unknownAction,
  unknownOption,
  verbDoesNotSupportTarget,
  verbDoesntSupportTarget,
  verbRequiresFileTarget,
  verbRequiresNoSession,
  verbRequiresNoToFile,
  verbRequiresNoWithFile,
  verbRequiresSessionTarget,
  verbRequiresSocketTarget,
  verbRequiresTarget,
  verbRequiresTargetButGot,
  versionMismatch,

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
  const DiagnosticParameter requiredTarget = DiagnosticParameter.requiredTarget;
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
          "Try removing 'in session $sessionName'.";

    case DiagnosticKind.cantPerformVerbIn:
      return "Can't perform '$verb' in '$target'.";

    case DiagnosticKind.cantPerformVerbTo:
      return "Can't perform '$verb' to '$target'.";

    case DiagnosticKind.cantPerformVerbWith:
      return "Can't perform '$verb' with '$target'.";

    case DiagnosticKind.verbRequiresSessionTarget:
      return "Can't perform '$verb' without a session "
          "target. Try adding 'session <SESSION_NAME>' to the commmand line.";

    case DiagnosticKind.verbRequiresFileTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '$verb' without a file, but got '$target', which "
        "is not a file target. Try adding 'file' in front.";

    case DiagnosticKind.verbRequiresSocketTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '$verb' without a socket, but got '$target', "
        "which is not a socket. Try adding 'tcp_socket' in front.";

    case DiagnosticKind.verbDoesNotSupportTarget:
      return "'$verb' can't be performed on '$target'.";

    case DiagnosticKind.noSuchSession:
      return "Couldn't find a session called '$sessionName'. "
          "Try running 'fletch create session $sessionName'.";

    case DiagnosticKind.sessionAlreadyExists:
      return "Couldn't create session named '$sessionName'; "
          "A session called $sessionName already exists.";

    case DiagnosticKind.noFileTarget:
      return "No file provided. Try adding <FILE_NAME> to the command line.";

    case DiagnosticKind.noTcpSocketTarget:
      return "No TCP socket provided. "
          "Try adding 'tcp_socket HOST:PORT' to the command line.";

    case DiagnosticKind.expectedAPortNumber:
      return "Expected a port number, but got '$userInput'.";

    case DiagnosticKind.noAgentFound:
      return "No agent found in this session.";

    case DiagnosticKind.upgradeInvalidPackageName:
      return "A fletch-agent package must have a name of the form\n"
        "  fletch-agent_<version>_<platform>.deb.\n"
        "Try renaming the file to match this pattern.";

    case DiagnosticKind.socketAgentConnectError:
      return "Unable to establish connection to Fletch Agent on "
          "$address: $message.";

    case DiagnosticKind.socketVmConnectError:
      return
          "Unable to establish connection to Fletch VM on $address: $message.";

    case DiagnosticKind.socketAgentReplyError:
      return "Received invalid reply from Fletch Agent on $address: $message.";

    case DiagnosticKind.socketVmReplyError:
      return "Received invalid reply from Fletch VM on $address: $message.";

    case DiagnosticKind.attachToVmBeforeRun:
      return "Unable to run program without being attached to a VM. "
          "Try running 'fletch attach'.";

    case DiagnosticKind.compileBeforeRun:
      return "No program to run. Try running 'fletch compile'";

    case DiagnosticKind.missingToFile:
      return "No destination file provided. "
          "Try adding 'to <FILE_NAME>' to the command line";

    case DiagnosticKind.unknownOption:
      // TODO(lukechurch): Review UX.
      return "Unknown option: '$userInput'.";

    case DiagnosticKind.missingRequiredArgument:
      // TODO(lukechurch): Consider a correction message.
      return "Option '${DiagnosticParameter.userInput}' needs an argument.";

    case DiagnosticKind.missingSessionName:
      // TODO(karlklose,ahe): provide support to list choices here.
      return "Session name missing. Try adding a name after 'session'.";

    case DiagnosticKind.unexpectedArgument:
      // TODO(lukechurch): Review UX
      return "Option '${DiagnosticParameter.userInput}' doesn't take an "
          "argument. Try removing '=' from the command line.";

    case DiagnosticKind.settingsNotAMap:
      return "$uri: isn't a map.";

    case DiagnosticKind.settingsNotJson:
      return "$uri: unable to decode as JSON: $message.";

    case DiagnosticKind.settingsPackagesNotAString:
      return "$uri: 'packages' value isn't a String.";

    case DiagnosticKind.settingsOptionsNotAList:
      return "$uri: 'options' value isn't a List.";

    case DiagnosticKind.settingsOptionNotAString:
      return "$uri: found 'options' entry '$userInput' which isn't a String.";

    case DiagnosticKind.settingsDeviceTypeNotAString:
      return
        "$uri: found 'device_type' entry '$userInput' which isn't a String.";

    case DiagnosticKind.settingsDeviceTypeUnrecognized:
      return
        "$uri: found 'device_type' entry '$userInput' which is not one of"
        "the recognized device types 'embedded', 'mobile'.";

    case DiagnosticKind.settingsCompileTimeConstantAsOption:
      return "$uri: compile-time constants should be in "
          "the 'constants' map, not in 'options': '$userInput'.";

    case DiagnosticKind.settingsConstantsNotAMap:
      return "$uri: 'constants' value isn't a Map";

    case DiagnosticKind.settingsUnrecognizedConstantValue:
      return "$uri: found 'constant[$userInput]' value '$additionalUserInput' "
          "isn't a bool, int, or String.";

    case DiagnosticKind.settingsUnrecognizedKey:
      return "$uri: unexpected key '$userInput'.";

    case DiagnosticKind.settingsDeviceAddressNotAString:
      return "$uri: 'device_address' value '$userInput' isn't a String.";

    case DiagnosticKind.unknownAction:
      return "'$userInput' isn't a supported action. "
        "Try running 'fletch help'.";

    case DiagnosticKind.extraArguments:
      return "Unrecognized arguments: $userInput.";

    case DiagnosticKind.duplicatedIn:
      return "More than one 'in' clause: $preposition.";

    case DiagnosticKind.duplicatedTo:
      // TODO(ahe): This is getting a bit tedious by now. We really need to
      // figure out if we need to require exact prepostions.
      return "More than one 'to' clause: $preposition.";

    case DiagnosticKind.duplicatedWith:
      return "More than one 'with' clause: $preposition.";

    case DiagnosticKind.verbDoesntSupportTarget:
      return "Can't perform '$verb' with '$target'.";

    case DiagnosticKind.verbRequiresNoToFile:
      return "Can't perform '$verb' to '$userInput'.";

    case DiagnosticKind.verbRequiresNoWithFile:
      return "Can't perform '$verb' with '$userInput'.";

    case DiagnosticKind.verbRequiresTarget:
      return "Can't perform '$verb' without a '$requiredTarget'.";

    case DiagnosticKind.verbRequiresTargetButGot:
      return "Can't perform '$verb' without a '$requiredTarget', "
          "but got: '$target'.";

    case DiagnosticKind.expectedTargetButGot:
      return "Expected 'session(s)', 'class(s)', 'method(s)', 'file(s)', "
          "or 'all', but got: '$userInput'. Did you mean 'file $userInput'?";

    case DiagnosticKind.quitTakesNoArguments:
      return "Unexpected arguments. Try running 'fletch quit'.";

    case DiagnosticKind.busySession:
      return "Session '$sessionName' is in use, please try again shortly.";

    case DiagnosticKind.terminatedSession:
      return "Session '$sessionName' was terminated.";

    case DiagnosticKind.handShakeFailed:
      // TODO(ager): lukechurch: Should this ever happen during normal usage?
      // Should they report this to us as a bug?
      return "Connection rejected because of invalid handshake reply from "
          "VM on $address.";

    case DiagnosticKind.versionMismatch:
      // TODO(ager): lukechurch: Is there advice we can give here?
      // E.g. Consider upgrading your compiler? Do we have an easy place they
      // can go to do that? Are we considering adding a tool to auto-upgrade?
      return "Connection rejected because compiler and VM on $address "
          "have different versions. Compiler version: '$userInput' "
          "VM version: '$additionalUserInput'.";

    case DiagnosticKind.agentVersionMismatch:
      // TODO(wibling): lukechurch: Is there advice we can give here?
      // E.g. Consider upgrading your compiler? Do we have an easy place they
      // can go to do that? Are we considering adding a tool to auto-upgrade?
      return "Could not start vm on device because the compiler and the "
          "session's remote device have different versions.\n"
          "Compiler version: '$userInput'\n"
          "Device version: '$additionalUserInput'.\n"
          "Try running 'fletch x-upgrade agent with file <agent debian "
          "package> in session $sessionName'.";

    case DiagnosticKind.compilerVersionMismatch:
      return "Command failed because the running compiler and the "
          "Fletch Command Line Interface (CLI) have "
          "different versions.\nCompiler version: '$userInput'\n"
          "CLI version: '$additionalUserInput'.\n"
          "This can happen if you have recently updated you Fletch SDK. "
          "Try running 'fletch quit' and retry the command.";
  }
}
