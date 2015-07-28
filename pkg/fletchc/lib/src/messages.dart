// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.messages;

import 'diagnostic.dart' show
    Diagnostic, // For documentation only.
    DiagnosticParameter;

enum DiagnosticKind {
  internalError,
  verbRequiresSession,
  verbRequiresNoSession,
  verbRequiresSessionTarget,
  verbRequiresTarget,
  verbRequiresFileTarget,
  verbRequiresSocketTarget,
  noSuchSession,
  sessionAlreadyExists,
  noFileTarget,
  noTcpSocketTarget,
  expectedAPortNumber,
  socketConnectError,
  attachToVmBeforeRun,
  compileBeforeRun,
  noFile, // TODO(ahe): Remove when compile_and_run_verb.dart is removed.
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
  switch (kind) {
    case DiagnosticKind.internalError:
      return "Internal error: ${DiagnosticParameter.message}";

    case DiagnosticKind.verbRequiresSession:
      return "Can't perform '${DiagnosticParameter.verb}' without a session. "
          "Try adding 'in session SESSION_NAME'";

    case DiagnosticKind.verbRequiresNoSession:
      return "Can't perform '${DiagnosticParameter.verb}' in a session. "
          "Try removing 'in session ${DiagnosticParameter.sessionName}'";

    case DiagnosticKind.verbRequiresSessionTarget:
      return "Can't perform '${DiagnosticParameter.verb}' without a session "
          "target. Try adding 'session SESSION_NAME'";

    case DiagnosticKind.verbRequiresTarget:
      // TODO(lukechurch): Revisit this to improve suggestion text.
      return "Can't perform '${DiagnosticParameter.verb}' without a target. "
          "Try adding a thing or group of things.";

    case DiagnosticKind.verbRequiresFileTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '${DiagnosticParameter.verb}' without a file, "
          "but got '${DiagnosticParameter.target}'";

    case DiagnosticKind.verbRequiresSocketTarget:
      // TODO(ahe): Be more explicit about what is wrong with the target.
      return "Can't perform '${DiagnosticParameter.verb}' without a socket, "
          "but got '${DiagnosticParameter.target}'";

    case DiagnosticKind.noSuchSession:
      // TODO(lukechurch): Ensure UX repair text is good.
      return "No session named: '${DiagnosticParameter.sessionName}'. "
          "Try running 'fletch create session "
          "${DiagnosticParameter.sessionName}'";

    case DiagnosticKind.sessionAlreadyExists:
      return "Can't create session named '${DiagnosticParameter.sessionName}'; "
          "There already is a session named "
          "'${DiagnosticParameter.sessionName}'.";

    case DiagnosticKind.noFileTarget:
      return "No file provided. "
          "Try adding 'file FILE_NAME' to the command line";

    case DiagnosticKind.noTcpSocketTarget:
      return "No TCP socket provided. "
          "Try adding 'tcp_socket HOST:PORT' to the command line";

    case DiagnosticKind.expectedAPortNumber:
      return
          "Expected a port number, but got '${DiagnosticParameter.userInput}'";

    case DiagnosticKind.socketConnectError:
      return
          "Unable to establish connection to "
          "${DiagnosticParameter.address}: ${DiagnosticParameter.message}";

    case DiagnosticKind.attachToVmBeforeRun:
      return "Unable to run program without being attached to a VM. "
          "Try running 'fletch attach'";

    case DiagnosticKind.compileBeforeRun:
      return "No program to run. Try running 'fletch compile'";

    case DiagnosticKind.noFile:
      // TODO(ahe): Remove this message when compile_and_run_verb.dart is
      // removed.
      return "No file  provided. Try adding 'FILE_NAME' to the command line";
  }
}
