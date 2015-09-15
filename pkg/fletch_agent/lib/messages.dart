// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// This comment describes the Fletch Agent's request and reply message format.
///
/// Message requests all start with the following header:
///
///    -----------------------------------------
///    | Command (16 bits) | Version (16 bits) |
///    -----------------------------------------
///    |  MSG ID (16 bits) | Unused (16 bits)  |
///    -----------------------------------------
///
/// Field descriptions:
///
/// Command: Identifies the requested action.
/// Version: used to determine if the server supports the client's request.
/// Msg ID: used to correlate a reply with the sender.
///
/// The request header is immediately followed by the relevant payload data for
/// the given command. See details for payloads below.
///
/// All requests have a related reply with the following reply header.
///
///    -----------------------------------------
///    | Msg ID (16 bits)  | Result (16 bits)  |
///    -----------------------------------------
///
/// Field descriptions:
///
/// Msg ID: used to correlate a reply with the sender.
/// Result: Can be success (0) or failure (a positive number)
///
/// The reply header is immediately followed by the relevant payload data for
/// the related request's command. See details for payloads below.
///
/// Command descriptions:
///
/// Below follows a description of request/reply payloads for a given command.
/// Each payload is always preceded by the corresponding header.
///
/// START_VM:
///   Start a new Fletch VM and return the vm's id and port on which it is
///   listening.
/// Request Payload:
///   None.
/// Reply Payload on success:
///   -----------------------------------------
///   | VM ID (16 bits)   | VM Port (16 bits) |
///   -----------------------------------------
/// Reply Payload on failure:
///   None.
///
/// STOP_VM:
///   Stop the VM specified by the given vm id.
/// Request Payload:
///   -----------------------------------------
///   | VM ID (16 bits)   | Unused (16 bits)  |
///   -----------------------------------------
/// Reply Payload on success:
///   None.
/// Reply Payload on failure:
///   None.
///
/// LIST_VMS:
///   This command lists the currently running Fletch VMs.
/// Request Payload:
///   None.
/// Reply Payload on success:
///   -----------------------------------------
///   |         Number of VMs (32 bits)       |
///   -----------------------------------------
///   | VM ID (16 bits)   | VM Port (16 bits) |
///   -----------------------------------------
///   | VM ID (16 bits)   | VM Port (16 bits) |
///   -----------------------------------------
///   | VM ID (16 bits)   | VM Port (16 bits) |
///   -----------------------------------------
///   ... a vm id and port pair per vm.
///
/// Reply Payload on failure:
///   None.
///
/// UPGRADE_VM:
///   This command is used to update the Fletch VM binary on the device.
/// Request Payload:
///   -----------------------------------------
///   |  VM binary length in bytes (32 bits)  |
///   -----------------------------------------
///   ... the vm binary bytes
///
/// Reply Payload on success:
///   None.
/// Reply Payload on failure:
///   None.

library fletch_agent.messages;

import 'dart:typed_data';

/// Current Fletch Agent version
const int AGENT_VERSION = 1;

class RequestHeader {
  // Supported commands.
  static const int START_VM = 0;
  static const int STOP_VM = 1;
  static const int LIST_VMS = 2;
  static const int UPGRADE_VM = 3;
  static const int FLETCH_VERSION = 4;

  // Wire size (bytes) of the RequestHeader.
  static const int WIRE_SIZE = 8;

  final int command;
  final int version;
  final int id;
  final int _reserved;

  RequestHeader(this.command, this.version, this.id, [this._reserved = 0]);

  factory RequestHeader.fromBuffer(ByteBuffer header) {
    assert(header.lengthInBytes >= WIRE_SIZE);
    // The network byte order is big endian.
    var cmd = readUint16(header, 0);
    var version = readUint16(header, 2);
    var id = readUint16(header, 4);
    var reserved = readUint16(header, 6);
    return new RequestHeader(cmd, version, id, reserved);
  }

  ByteBuffer get toBuffer {
    var buffer = new Uint16List(4).buffer;
    writeUint16(buffer, 0, command);
    writeUint16(buffer, 2, version);
    writeUint16(buffer, 4, id);
    writeUint16(buffer, 6, _reserved);
    return buffer;
  }
}

class ReplyHeader {
  /// Error codes.
  static const int SUCCESS = 0;
  static const int UNKNOWN_COMMAND = 1;
  static const int INVALID_PAYLOAD = 2;
  static const int UNSUPPORTED_VERSION = 3;
  static const int START_VM_FAILED = 4;
  static const int UNKNOWN_VM_ID = 5;

  // Wire size (bytes) of the ReplyHeader.
  static const int WIRE_SIZE = 4;

  final int id;
  final int result;

  ReplyHeader(this.id, this.result);

  factory ReplyHeader.fromBuffer(ByteBuffer buffer) {
    assert(buffer.lengthInBytes >= WIRE_SIZE);
    return new ReplyHeader(readUint16(buffer, 0), readUint16(buffer, 2));
  }

  ByteBuffer get toBuffer {
    var buffer = new Uint16List(2).buffer;
    writeUint16(buffer, 0, id);
    writeUint16(buffer, 2, result);
    return buffer;
  }
}

// Utility methods to read and write 16 and 32 bit entities from/to big endian.
int readUint16(ByteBuffer buffer, int offset) {
  // Goto right offset
  var b = buffer.asUint8List(offset, 2);
  return b[0] << 8 | b[1];
}

void writeUint16(ByteBuffer buffer, int offset, int value) {
  // Goto right offset
  var b = buffer.asUint8List(offset, 2);
  b[0] = value >> 8 & 0xff;
  b[1] = value & 0xff;
}

int readUint32(ByteBuffer buffer, int offset) {
  // Goto right offset
  var b = buffer.asUint8List(offset, 4);
  return b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3];
}

void writeUint32(ByteBuffer buffer, int offset, int value) {
  // Goto right offset
  var b = buffer.asUint8List(offset, 4);
  b[0] = value >> 24 & 0xff;
  b[1] = value >> 16 & 0xff;
  b[2] = value >> 8 & 0xff;
  b[3] = value & 0xff;
}