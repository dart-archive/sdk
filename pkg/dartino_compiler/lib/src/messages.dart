// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.messages;

import 'diagnostic.dart' show
    Diagnostic, // For documentation only.
    DiagnosticParameter;

enum DiagnosticKind {
  agentVersionMismatch,
  boardNotFound,
  busySession,
  cantPerformVerbIn,
  cantPerformVerbTo,
  cantPerformVerbWith,
  compilerVersionMismatch,
  duplicatedFor,
  duplicatedIn,
  duplicatedTo,
  duplicatedWith,
  expectedAPortNumber,
  expectedTargetButGot,
  extraArguments,
  handShakeFailed,
  illegalDefine,
  infoFileNotFound,
  internalError,
  missingForName,
  missingProjectPath,
  missingRequiredArgument,
  malformedInfoFile,
  missingNoun,
  missingSessionName,
  missingToFile,
  noAgentFound,
  noFileTarget,
  noSuchSession,
  noConnectionTarget,
  optionsObsolete,
  projectAlreadyExists,
  quitTakesNoArguments,
  sessionAlreadyExists,
  sessionInvalidState,
  settingsCompileTimeConstantAsOption,
  settingsConstantsNotAMap,
  settingsDeviceAddressNotAString,
  settingsDeviceTypeNotAString,
  settingsDeviceTypeUnrecognized,
  settingsIncrementalModeNotAString,
  settingsIncrementalModeUnrecognized,
  settingsNotAMap,
  settingsNotJson,
  settingsOptionNotAString,
  settingsOptionsNotAList,
  settingsPackagesNotAString,
  settingsUnrecognizedConstantValue,
  settingsUnrecognizedKey,
  snapshotHashMismatch,
  socketAgentConnectError,
  socketAgentReplyError,
  socketVmConnectError,
  socketVmReplyError,
  terminatedSession,
  toolsNotInstalled,
  unexpectedArgument,
  unknownAction,
  unknownNoun,
  unknownOption,
  unsupportedPlatform,
  upgradeInvalidPackageName,
  verbDoesNotSupportTarget,
  verbDoesntSupportTarget,
  verbRequiresFileTarget,
  verbRequiresNoFor,
  verbRequiresNoSession,
  verbRequiresNoToFile,
  verbRequiresNoWithFile,
  verbRequiresSessionTarget,
  verbRequiresConnectionTarget,
  verbRequiresSpecificTarget,
  verbRequiresSpecificTargetButGot,
  verbRequiresTarget,
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
/// Where appropriate, we follow the [Google design guidelines](https://www.google.com/design/spec/style/writing.html)
/// for writing messages to the user. With respect to punctuation, we interpret
/// error messages as parallel labels, meaning they should use full sentences,
/// that is, starting with a capital letter and terminated with punctuation
/// (see [Capitalization & punctuation](https://www.google.com/design/spec/style/writing.html#writing-capitalization-punctuation)).
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
  const DiagnosticParameter nouns = DiagnosticParameter.nouns;
  const DiagnosticParameter boardNames = DiagnosticParameter.boardNames;
  const DiagnosticParameter sessionName = DiagnosticParameter.sessionName;
  const DiagnosticParameter target = DiagnosticParameter.target;
  const DiagnosticParameter requiredTarget = DiagnosticParameter.requiredTarget;
  const DiagnosticParameter userInput = DiagnosticParameter.userInput;
  const DiagnosticParameter additionalUserInput =
      DiagnosticParameter.additionalUserInput;
  const DiagnosticParameter address = DiagnosticParameter.address;
  const DiagnosticParameter preposition = DiagnosticParameter.preposition;
  const DiagnosticParameter uri = DiagnosticParameter.uri;
  const DiagnosticParameter fixit = DiagnosticParameter.fixit;

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

    case DiagnosticKind.verbRequiresConnectionTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '$verb' without a connection endpoint,"
          "but got '$target', which is not a connection endpoint. "
          "Try adding 'tcp_socket' or 'tty' in front.";

    case DiagnosticKind.verbDoesNotSupportTarget:
      return "'$verb' can't be performed on '$target'.";

    case DiagnosticKind.projectAlreadyExists:
      return "Project already exists: $uri";

    case DiagnosticKind.optionsObsolete:
      return "The 'options' setting (value $userInput) is renamed to "
          "'compiler_options', please update your settings-file: $uri";

    case DiagnosticKind.missingForName:
      return "Missing 'for <board-name>' "
          "where <board-name> is one of $boardNames";

    case DiagnosticKind.boardNotFound:
      return "Couldn't find a board named '$userInput'. "
          "Try one of these board names: $boardNames";

    case DiagnosticKind.noSuchSession:
      return "Couldn't find a session called '$sessionName'. "
          "Try running 'dartino create session $sessionName'.";

    case DiagnosticKind.sessionAlreadyExists:
      return "Couldn't create session named '$sessionName'; "
          "A session called $sessionName already exists.";

    case DiagnosticKind.sessionInvalidState:
      return "Session '$sessionName' not in a valid state; "
          "Please stop attached vm, run 'dartino quit' and retry.";

    case DiagnosticKind.noFileTarget:
      return "No file provided. Try adding <FILE_NAME> to the command line.";

    case DiagnosticKind.noConnectionTarget:
      return "No connection endpoint provided. "
          "Try adding 'tcp_socket HOST:PORT' or 'tty /dev/device' to the "
          "command line.";

    case DiagnosticKind.expectedAPortNumber:
      return "Expected a port number, but got '$userInput'.";

    case DiagnosticKind.noAgentFound:
      return "No agent found in this session.";

    case DiagnosticKind.upgradeInvalidPackageName:
      return "A dartino-agent package must have a name of the form\n"
        "  dartino-agent_<version>_<platform>.deb.\n"
        "Try renaming the file to match this pattern.";

    case DiagnosticKind.socketAgentConnectError:
      return "Unable to establish connection to Dartino Agent on "
          "$address: $message.";

    case DiagnosticKind.socketVmConnectError:
      return
          "Unable to establish connection to Dartino VM on $address: $message.";

    case DiagnosticKind.socketAgentReplyError:
      return "Received invalid reply from Dartino Agent on $address: $message.";

    case DiagnosticKind.socketVmReplyError:
      return "Received invalid reply from Dartino VM on $address: $message.";

    case DiagnosticKind.attachToVmBeforeRun:
      return "Unable to run program without being attached to a VM. "
          "Try running 'dartino attach'.";

    case DiagnosticKind.compileBeforeRun:
      return "No program to run. Try running 'dartino compile'";

    case DiagnosticKind.missingToFile:
      return "No destination file provided. "
          "Try adding 'to <FILE_NAME>' to the command line";

    case DiagnosticKind.unknownOption:
      // TODO(lukechurch): Review UX.
      return "Unknown option: '$userInput'.";

    case DiagnosticKind.unsupportedPlatform:
      // TODO(lukechurch): Review UX.
      return "Unsupported platform: $message.";

    case DiagnosticKind.missingProjectPath:
      return "Project path missing. Try adding the path of a directory"
          " to be created after 'project'.";

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
      return "$uri: 'packages' value '$userInput' isn't a String.";

    case DiagnosticKind.settingsOptionsNotAList:
      return "$uri: '$additionalUserInput' value '$userInput' isn't a List.";

    case DiagnosticKind.settingsDeviceTypeNotAString:
      return "$uri: 'device_type' value '$userInput' isn't a String.";

    case DiagnosticKind.settingsIncrementalModeNotAString:
      return "$uri: 'incremental_mode' value '$userInput' isn't a String.";

    case DiagnosticKind.settingsOptionNotAString:
      return "$uri: found '$additionalUserInput' entry '$userInput' "
          "which isn't a String.";

    case DiagnosticKind.settingsDeviceTypeNotAString:
      return
          "$uri: found 'device_type' entry '$userInput' which isn't a String.";

    case DiagnosticKind.settingsDeviceTypeUnrecognized:
      return "$uri: found 'device_type' entry '$userInput' which is not one of "
          "the recognized device types 'embedded', 'mobile'.";

    case DiagnosticKind.settingsIncrementalModeUnrecognized:
      return "$uri: found 'incremental_mode' entry '$userInput' which is not "
          "one of the recognized modes 'none', 'production', or "
          "'experimental'.";

    case DiagnosticKind.settingsCompileTimeConstantAsOption:
      return "$uri: compile-time constants should be in "
          "the 'constants' map, not in '$additionalUserInput': "
          "'$userInput'.";

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
        "Try running 'dartino help'.";

    case DiagnosticKind.missingNoun:
      return "'$verb' must be followed by one of $nouns. "
        "Alternately try running 'dartino help'.";

    case DiagnosticKind.unknownNoun:
      return "'$verb $userInput' isn't a supported action. "
        "Try '$verb' followed by one of $nouns, "
        "or try running 'dartino help'.";

    case DiagnosticKind.extraArguments:
      return "Unrecognized arguments: $userInput.";

    case DiagnosticKind.duplicatedFor:
      return "More than one 'for' clause: $preposition.";

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

    case DiagnosticKind.verbRequiresNoFor:
      return "Can't perform '$verb' for '$userInput'.";

    case DiagnosticKind.verbRequiresNoToFile:
      return "Can't perform '$verb' to '$userInput'.";

    case DiagnosticKind.verbRequiresNoWithFile:
      return "Can't perform '$verb' with '$userInput'.";

    case DiagnosticKind.verbRequiresSpecificTarget:
      return "Can't perform '$verb' without a '$requiredTarget'.";

    case DiagnosticKind.verbRequiresTarget:
      return "Can't perform '$verb' without a target.";

    case DiagnosticKind.verbRequiresSpecificTargetButGot:
      return "Can't perform '$verb' without a '$requiredTarget', "
          "but got: '$target'.";

    case DiagnosticKind.expectedTargetButGot:
      return "Expected 'session(s)', 'class(s)', 'method(s)', 'file(s)', "
          "or 'all', but got: '$userInput'. Did you mean 'file $userInput'?";

    case DiagnosticKind.quitTakesNoArguments:
      return "Unexpected arguments. Try running 'dartino quit'.";

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

    case DiagnosticKind.snapshotHashMismatch:
      return "The VM on $address runs a snapshot with a hash-tag `$userInput`. "
          "The info file at $uri has hash-tag `$additionalUserInput`. "
          "Make sure you are using the same file as when you exported the "
          "program.";

    case DiagnosticKind.agentVersionMismatch:
      // TODO(wibling): lukechurch: Is there advice we can give here?
      // E.g. Consider upgrading your compiler? Do we have an easy place they
      // can go to do that? Are we considering adding a tool to auto-upgrade?
      return """
Could not start vm on device because the compiler and the
session's remote device have different versions.
Compiler version: '$userInput'
Device version: '$additionalUserInput'.
$fixit""";

    case DiagnosticKind.compilerVersionMismatch:
      return "Command failed because the running compiler and the "
          "Dartino Command Line Interface (CLI) have "
          "different versions.\nCompiler version: '$userInput'\n"
          "CLI version: '$additionalUserInput'.\n"
          "This can happen if you have recently updated you Dartino SDK. "
          "Try running 'dartino quit' and retry the command.";

    case DiagnosticKind.illegalDefine:
      return "The define $userInput has an illegal value part: "
             "$additionalUserInput.";

    case DiagnosticKind.toolsNotInstalled:
      return "Required third party tools GCC ARM Embedded and OpenOCD "
          "have not been installed.\n\nTry running 'dartino x-download-tools' "
          "to add these tools to the Dartino install.";

    case DiagnosticKind.infoFileNotFound:
      return "Could not find the debug information at $uri.";

    case DiagnosticKind.malformedInfoFile:
      return "Parse error when reading $uri.\n"
          "Ensure this is a .info.json file generated by dartino.";
  }
}

const analyticsOptInPrompt =
""""Welcome to Dartino! We collect anonymous usage statistics and crash reports
in order to improve the tool (see http://goo.gl/27JjhU for details).

Would you like to opt-in to help us improve Dartino (Y/n)?""";

const analyticsOptInNotification = "\nThank you for helping us improve Dartino!\n";

const analyticsOptOutNotification =
    "\nNo anonymous usage statistics or crash reports will be sent.\n";

const analyticsRecordChoiceFailed = "Failed to record opt-in choice.";
