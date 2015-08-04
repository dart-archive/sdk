// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.attach_verb;

import 'infrastructure.dart';

import 'dart:io' show
    InternetAddress,
    Socket,
    SocketException;

import '../driver/driver_commands.dart' show
    handleSocketErrors;

import '../../commands.dart' as commands_lib;

import 'documentation.dart' show
    attachDocumentation;

const Verb attachVerb = const Verb(
    attach, attachDocumentation, requiresSession: true, requiresTarget: true,
    supportsTarget: TargetKind.TCP_SOCKET);

Future<int> attach(AnalyzedSentence sentence, VerbContext context) async {
  List<String> address = sentence.targetName.split(":");
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

  SessionState sessionState = SessionState.current;

  FletchVmSession session =
      new FletchVmSession(handleSocketErrors(socket, "vmSocket"),
                          sessionState.stdoutSink,
                          sessionState.stderrSink);

  // Enable debugging as a form of handshake.
  await session.runCommand(const commands_lib.Debugging());

  print("Connected to Fletch VM on TCP socket ${socket.port} -> $remotePort");

  sessionState.vmSession = session;

  return 0;
}
