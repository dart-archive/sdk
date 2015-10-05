// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch_agent.agent_connection;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'messages.dart';

/// This class is used to connect to the Fletch Agent from Dart code. Ie. it
/// cannot be used from Fletch code as it is depending on the dart:io Socket
/// class.
/// The class is only for making a one-shot request/reply. The peer socket is
/// closed after handling the request. This is similar to HTTP without
/// keep-alive.
/// The caller/user of this class must handle any errors occurring on the
/// socket.done future as this class is not handling that.
class AgentConnection {
  final Socket socket;

  AgentConnection(this.socket);

  Future<VmData> startVm() async {
    var request = new StartVmRequest();
    var replyBuffer = await sendRequest(request);
    var reply = new StartVmReply.fromBuffer(replyBuffer);
    if (reply.result == ReplyHeader.START_VM_FAILED) {
      throw new AgentException('Failed to start new Fletch VM.');
    } else if (reply.result != ReplyHeader.SUCCESS) {
      throw new AgentException(
          'Failed to spawn new VM with unexpected error: ${reply.result}');
    }
    return new VmData(reply.vmId, reply.vmPort);
  }

  Future stopVm(int vmId) async {
    var request = new StopVmRequest(vmId);
    var replyBuffer = await sendRequest(request);
    var reply = new StopVmReply.fromBuffer(replyBuffer);
    if (reply.result == ReplyHeader.UNKNOWN_VM_ID) {
      throw new AgentException('Could not stop VM. Unknown vm id: $vmId');
    } else if (reply.result != ReplyHeader.SUCCESS) {
      throw new AgentException(
          'Failed to stop VM with unexpected error: ${reply.result}');
    }
  }

  Future signalVm(int vmId, int signal) async {
    var request = new SignalVmRequest(vmId, signal);
    var replyBuffer = await sendRequest(request);
    var reply = new SignalVmReply.fromBuffer(replyBuffer);
    if (reply.result == ReplyHeader.UNKNOWN_VM_ID) {
      throw new AgentException('Could not signal VM. Unknown vm id: $vmId');
    } else if (reply.result != ReplyHeader.SUCCESS) {
      throw new AgentException(
          'Failed to signal VM with unexpected error: ${reply.result}');
    }
  }

  Future<List<int>> listVms() async {
    throw new AgentException('Not implemented');
  }

  Future UpgradeVm(List<int> vmBinary) async {
    throw new AgentException('Not implemented');
  }

  Future<int> fletchVesion() async {
    throw new AgentException('Not implemented');
  }

  Future<ByteBuffer> sendRequest(RequestHeader request) async {
    socket.add(request.toBuffer().asUint8List());
    var replyBytes = await socket.fold([], (p, e) => p..addAll(e));
    return new Uint8List.fromList(replyBytes).buffer;
  }
}

class VmData {
  final int id;
  final int port;

  VmData(this.id, this.port);
}

class AgentException implements Exception {
  String message;
  String toString() => 'AgentException($message)';

  AgentException(this.message);
}
