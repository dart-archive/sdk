// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.attach_verb;

import 'dart:async' show
    Future,
    StreamIterator;

import 'dart:io' show
    InternetAddress,
    Socket,
    SocketException;

import 'verbs.dart' show
    Sentence,
    SharedTask,
    TargetKind,
    Verb,
    VerbContext;

import '../driver/sentence_parser.dart' show
    NamedTarget;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

import '../driver/driver_commands.dart' show
    Command,
    CommandSender,
    handleSocketErrors;

import '../driver/session_manager.dart' show
    SessionState;

import '../../commands.dart' as commands_lib;

import '../../session.dart' show
    FletchVmSession;

import 'documentation.dart' show
    attachDocumentation;

const Verb attachVerb =
    const Verb(attach, attachDocumentation, requiresSession: true);

Future<int> attach(Sentence sentence, VerbContext context) async {
  if (sentence.target == null) {
    throwFatalError(DiagnosticKind.noTcpSocketTarget);
  }
  if (sentence.target.kind != TargetKind.TCP_SOCKET) {
    throwFatalError(
        DiagnosticKind.attachRequiresSocketTarget, target: sentence.target);
  }
  NamedTarget target = sentence.target;
  List<String> address = target.name.split(":");
  String host;
  int port;
  if (address.length == 1) {
    host = InternetAddress.LOOPBACK_IP_V4.address;
    port = int.parse(
        address[0],
        onError: (String source) {
          host = source;
          return 0;
        });
  } else {
    host = address[0];
    port = int.parse(
        address[1],
        onError: (String source) {
          throwFatalError(
              DiagnosticKind.expectedAPortNumber, userInput: source);
        });
  }

  await context.performTaskInWorker(new AttachTask(host, port));

  return null;
}

class AttachTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String host;

  final int port;

  const AttachTask(this.host, this.port);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return attachTask(host, port);
  }
}

Future<int> attachTask(String host, int port) async {
  Socket socket = await Socket.connect(host, port).catchError(
      (SocketException error) {
        String message = error.message;
        if (error.osError != null) {
          message = error.osError.message;
        }
        throwFatalError(
            DiagnosticKind.socketConnectError,
            address: '$host:$port', message: message);
      }, test: (e) => e is SocketException);
  String remotePort = "?";
  try {
    remotePort = "${socket.remotePort}";
  } catch (_) {
    // Ignored, socket.remotePort may fail if the socket was closed on the
    // other side.
  }

  FletchVmSession session =
      new FletchVmSession(handleSocketErrors(socket, "vmSocket"), null, null);

  // Enable debugging as a form of handshake.
  await session.runCommand(const commands_lib.Debugging());

  print("Connected to Fletch VM on TCP socket ${socket.port} -> $remotePort");

  SessionState.current.vmSession = session;

  return 0;
}
