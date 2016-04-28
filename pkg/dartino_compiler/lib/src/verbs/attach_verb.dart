// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.attach_verb;

import 'infrastructure.dart';

import 'documentation.dart' show
    attachDocumentation;

import '../hub/sentence_parser.dart' show
    connectionTargets;

import '../worker/developer.dart' show
    Address,
    attachToVmTcp,
    attachToVmTty,
    parseAddress;

const Action attachAction = const Action(
    attach, attachDocumentation, requiresSession: true,
    supportedTargets: connectionTargets,
    requiresTarget: true);

Future<int> attach(AnalyzedSentence sentence, VerbContext context) {
  switch (sentence.target.kind) {
    case TargetKind.TCP_SOCKET:
      Address address = parseAddress(sentence.targetName);
      return context.performTaskInWorker(
          new AttachTcpTask(address.host, address.port));
    case TargetKind.TTY:
      return context.performTaskInWorker(
          new AttachTtyTask(sentence.targetName));
    default:
      throw "Unsupported target.";
  }
}

class AttachTcpTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String host;

  final int port;

  const AttachTcpTask(this.host, this.port);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return attachTcpTask(host, port);
  }
}

Future<int> attachTcpTask(String host, int port) async {
  SessionState state = SessionState.current;

  // Cleanup previous session if any.
  await state.terminateSession();

  state.explicitAttach = true;
  await attachToVmTcp(host, port, state);
  print("Attached to $host:$port");
  return 0;
}

class AttachTtyTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final String ttyDevice;

  const AttachTtyTask(this.ttyDevice);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
    return attachTtyTask(ttyDevice);
  }
}

Future<int> attachTtyTask(String ttyDevice) async {
  SessionState state = SessionState.current;

  // Cleanup previous session if any.
  await state.terminateSession();

  state.explicitAttach = true;
  await attachToVmTty(ttyDevice, state);
  print("Attached to $ttyDevice");
  return 0;
}
