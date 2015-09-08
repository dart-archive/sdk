// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.attach_verb;

import 'infrastructure.dart';

import 'dart:io' show
    InternetAddress;

import 'documentation.dart' show
    attachDocumentation;

import '../driver/developer.dart' show
    attachToVm;

const Verb attachVerb = const Verb(
    attach, attachDocumentation, requiresSession: true,
    requiredTarget: TargetKind.TCP_SOCKET);

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
  await attachToVm(host, port, SessionState.current);
  return 0;
}
