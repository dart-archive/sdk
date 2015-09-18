// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:typed_data';

import '../lib/messages.dart';

void printUsage() {
  print('Usage:');
  print('The Fletch agent command line client supports the following flags');
  print('');
  print('  --port: specify the port on which to connect, default: 12121');
  print('  --host: specify the ip address on which to connect, default: '
      '127.0.0.1');
  print('  --cmd: specify the command to send to the Fletch agent, default: '
      'START_VM (0)');
  print('  --pid: specify the pid of the vm to stop, only used when cmd=1 '
      '(STOP_VM)');
  print('');
  exit(1);
}

// Small dart program to issue commands to the fletch agent.
void main(List<String> arguments) async {
  // Startup the agent listening on specified port.
  int port = 12121;
  String host = '127.0.0.1';
  int cmd = RequestHeader.START_VM;
  int id = 0;
  int pid;

  for (var argument in arguments) {
    var parts = argument.split('=');
    if (parts[0] == '--cmd') {
      if (parts.length != 2) {
        printUsage();
      }
      cmd = int.parse(parts[1]);
    } else if (parts[0] == '--id') {
      if (parts.length != 2) {
        printUsage();
      }
      id = int.parse(parts[1]);
    } else if (parts[0] == '--pid') {
      if (parts.length != 2) {
        printUsage();
      }
      pid = int.parse(parts[1]);
    } else if (parts[0] == '--host') {
      if (parts.length != 2) {
        printUsage();
      }
      host = parts[1];
    } else if (parts[0] == '--port') {
      if (parts.length != 2) {
        printUsage();
      }
      port = int.parse(parts[1]);
    }
  }
  if (cmd < 0 || cmd > 4) {
    print('Invalid command: $cmd');
    exit(1);
  }
  var socket = await Socket.connect(host, port);
  var header = new RequestHeader(cmd, AGENT_VERSION, id);
  ByteBuffer payload;
  // We set the expected reply length for each command here as a temporary
  // workaround for receiving partial replies, until we add a payload length
  // to the reply header.
  int replyLength;
  // Add payload
  switch (cmd) {
    case RequestHeader.START_VM:
      replyLength = ReplyHeader.WIRE_SIZE + 4;
      break;
    case RequestHeader.STOP_VM:
      if (pid == null) {
        print('Please specify which pid to stop with --pid=<pid>');
        exit(1);
      }
      replyLength = ReplyHeader.WIRE_SIZE;
      // The payload consists of a 16 bit vm id and 16 bit reserved.
      payload = new ByteData(4)
          ..setUint16(0, pid)  // vm id
          ..setUint16(2, 0);  // reserved
      break;
    case RequestHeader.LIST_VMS:
      // HACK this cannot be hard coded, add payload length field to header.
      replyLength = ReplyHeader.WIRE_SIZE + 16;
      break;
    case RequestHeader.UPGRADE_VM:
      replyLength = ReplyHeader.WIRE_SIZE;
      payload = new ByteData(132);
      // Write the binary data length at offset 0 and the bytes at offset 4.
      print('Sending ${payload.length - 4} bytes');
      payload.setUint32(0, payload.length - 4);
      var data = payload.buffer.asUint8List(4, payload.length - 4);
      for (int i = 0; i < data.length; ++i) {
        data[i] = i + 42;
      }
      break;
    case RequestHeader.FLETCH_VERSION:
      replyLength = ReplyHeader.WIRE_SIZE + 4;
      break;
  }
  socket.add(header.toBuffer.asUint8List());
  if (payload != null) {
    socket.add(payload.buffer.asUint8List());
  }
  var replyData = await socket.fold([], (p, e) => p..addAll(e));
  var data = new Uint8List.fromList(replyData).buffer;
  print('Received reply of length ${data.lengthInBytes} bytes.');
  if (data.lengthInBytes < ReplyHeader.WIRE_SIZE) {
    print('Too little data received');
    socket.close();
    exit(1);
  }
  var replyHeader = new ReplyHeader.fromBuffer(data);
  print('Received reply with id ${replyHeader.id} and result '
      '${replyHeader.result}');
  if (data.lengthInBytes < replyLength) {
    print(
        'Received less than expected payload data ($replyLength) in the reply');
    socket.close();
    exit(1);
  }
  if (replyHeader.id != id) {
    print('Received out of sync message. Expected id $id and got '
          'id ${replyHeader.id}');
    socket.close();
    exit(1);
  }
  if (replyHeader.result == ReplyHeader.SUCCESS) {
    if (cmd == RequestHeader.START_VM) {
      // Print the received vm id and vm port
      var vmId = readUint16(data, ReplyHeader.WIRE_SIZE);
      var vmPort = readUint16(data, ReplyHeader.WIRE_SIZE + 2);
      print('Started vm with pid: $vmId and port $vmPort.');
    } else if (cmd == RequestHeader.LIST_VMS) {
      var numVms = readUint32(data, ReplyHeader.WIRE_SIZE);
      int offset = ReplyHeader.WIRE_SIZE + 4;
      for (int i = 0; i < numVms; ++i) {
        var vmId = readUint16(data, offset);
        offset += 2;
        var vmPort = readUint16(data, offset);
        offset += 2;
        print('Found vm with id: $vmId and port $vmPort.');
      }
    } else if (cmd == RequestHeader.FLETCH_VERSION) {
      var version = readUint32(data, ReplyHeader.WIRE_SIZE);
      print('Got Fletch version $version');
    }
  }
  replyData = [];
  socket.close();
}
