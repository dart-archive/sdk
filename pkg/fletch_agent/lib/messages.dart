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
///    |  Msg ID (16 bits) | Unused (16 bits)  |
///    -----------------------------------------
///    |        Payload Length (32 bits)       |
///    -----------------------------------------
///
/// Field descriptions:
///
/// Command: Identifies the requested action.
/// Version: used to determine if the server supports the client's request.
/// Msg ID: used to correlate a reply with the sender.
/// Unused: Reserved for future uses.
/// Payload Length: Length of request payload in bytes.
///
/// The request header is immediately followed by the relevant payload data for
/// the given command. See details for payloads below.
///
/// All requests have a related reply with the following reply header.
///
///    ---------------------------------------
///    | Msg ID (16 bits) | Result (16 bits) |
///    ---------------------------------------
///    |        Payload Length (32 bits)     |
///    ---------------------------------------
///
/// Field descriptions:
///
/// Msg ID: used to correlate a reply with the sender.
/// Result: Can be success (0) or failure (a positive number).
/// Payload length: Length of reply payload in bytes.
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
///   ---------------------------------------
///   | VM ID (16 bits)   | VM ID (16 bits) |
///   ---------------------------------------
///   | VM ID (16 bits)   | VM ID (16 bits) |
///   ---------------------------------------
///   | VM ID (16 bits)   | VM ID (16 bits) |
///   ---------------------------------------
///   ...
///
/// Reply Payload on failure:
///   None.
///
/// UPGRADE_VM:
///   This command is used to update the Fletch VM binary on the device.
/// Request Payload:
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

/// Default agent port
const int AGENT_DEFAULT_PORT = 12121;

class RequestHeader {
  static const int START_VM = 0;
  static const int STOP_VM = 1;
  static const int LIST_VMS = 2;
  static const int UPGRADE_VM = 3;
  static const int FLETCH_VERSION = 4;

  // Wire size (bytes) of the RequestHeader.
  static const int HEADER_SIZE = 12;

  static int _nextMessageId = 1;
  static int get nextMessageId {
    if ((_nextMessageId & 0xFFFF) == 0) {
      _nextMessageId = 1;
    }
    return _nextMessageId++;
  }

  final int command;
  final int version;
  final int id;
  final int reserved;
  final int payloadLength;

  RequestHeader(
      this.command,
      {this.version: AGENT_VERSION,
       int id,
       this.reserved: 0,
       this.payloadLength: 0})
      : id = id != null ? id : nextMessageId;

  factory RequestHeader.fromBuffer(ByteBuffer buffer) {
    if (buffer.lengthInBytes < HEADER_SIZE) {
      throw new MessageDecodeException(
          'Insufficient bytes (${buffer.lengthInBytes}) to decode header: '
          '${buffer.asUint8List()})');
    }
    // The network byte order is big endian.
    int cmd = readUint16(buffer, 0);
    int version = readUint16(buffer, 2);
    int id = readUint16(buffer, 4);
    int reserved = readUint16(buffer, 6);
    int payloadLength = readUint32(buffer, 8);
    return new RequestHeader(cmd, version: version, id: id, reserved: reserved,
        payloadLength: payloadLength);
  }

  ByteBuffer toBuffer() {
    var buffer = new Uint8List(HEADER_SIZE).buffer;
    _writeHeader(buffer);
    return buffer;
  }

  void _writeHeader(ByteBuffer buffer) {
    writeUint16(buffer, 0, command);
    writeUint16(buffer, 2, version);
    writeUint16(buffer, 4, id);
    writeUint16(buffer, 6, reserved);
    writeUint32(buffer, 8, payloadLength);
  }
}

class StartVmRequest extends RequestHeader {
  StartVmRequest() : super(RequestHeader.START_VM);

  StartVmRequest.withHeader(RequestHeader header)
      : super(
            RequestHeader.START_VM,
            version: header.version,
            id: header.id,
            reserved: header.reserved);

  factory StartVmRequest.fromBuffer(ByteBuffer buffer) {
    var header = new RequestHeader.fromBuffer(buffer);
    assert(header != null);
    if (header.command != RequestHeader.START_VM || header.payloadLength != 0) {
      throw new MessageDecodeException(
          "Invalid StartVmRequest: ${buffer.asUint8List()}");
    }
    return new StartVmRequest.withHeader(header);
  }

  // A StartVmRequest has no payload so just use parent's toBuffer method.
}

class StopVmRequest extends RequestHeader {
  final int vmPid;
  final int unused;

  StopVmRequest(this.vmPid, {this.unused: 0})
      : super(RequestHeader.STOP_VM, payloadLength: 4);

  StopVmRequest.withHeader(RequestHeader header, this.vmPid, {this.unused: 0})
      : super(
            RequestHeader.STOP_VM,
            version: header.version,
            id: header.id,
            reserved: header.reserved);

  factory StopVmRequest.fromBuffer(ByteBuffer buffer) {
    if (buffer.lengthInBytes < RequestHeader.HEADER_SIZE + 4) {
      throw new MessageDecodeException(
          'Insufficient data for a StopVmRequest: ${buffer.asUint8List()}');
    }
    var header = new RequestHeader.fromBuffer(buffer);
    if (header.command != RequestHeader.STOP_VM || header.payloadLength != 4) {
      throw new MessageDecodeException(
          "Invalid StopVmRequest: ${buffer.asUint8List()}");
    }
    var vmPid = readUint16(buffer, RequestHeader.HEADER_SIZE);
    var unused = readUint16(buffer, RequestHeader.HEADER_SIZE + 2);
    return new StopVmRequest.withHeader(header, vmPid, unused: unused);
  }

  ByteBuffer toBuffer() {
    var buffer = new Uint8List(RequestHeader.HEADER_SIZE + 4).buffer;
    _writeHeader(buffer);
    writeUint16(buffer, RequestHeader.HEADER_SIZE, vmPid);
    writeUint16(buffer, RequestHeader.HEADER_SIZE + 2, unused);
    return buffer;
  }
}

class ListVmsRequest extends RequestHeader {
  ListVmsRequest() : super(RequestHeader.LIST_VMS);

  ListVmsRequest.withHeader(RequestHeader header)
      : super(
            RequestHeader.LIST_VMS,
            version: header.version,
            id: header.id,
            reserved: header.reserved);

  factory ListVmsRequest.fromBuffer(ByteBuffer buffer) {
    var header = new RequestHeader.fromBuffer(buffer);
    if (header.command != RequestHeader.LIST_VMS || header.payloadLength != 0) {
      throw new MessageDecodeException(
          "Invalid ListVmsRequest: ${buffer.asUint8List()}");
    }
    return new ListVmsRequest.withHeader(header);
  }

  // A ListVmsRequest has no payload so just use parent's toBuffer method.
}

class UpgradeVmRequest extends RequestHeader {
  final List<int> vmBinary;

  UpgradeVmRequest(List<int> vmBinary)
      : super(RequestHeader.UPGRADE_VM, payloadLength: vmBinary.length),
        vmBinary = vmBinary;

  UpgradeVmRequest.withHeader(RequestHeader header, List<int> vmBinary)
      : super(
            RequestHeader.UPGRADE_VM,
            version: header.version,
            id: header.id,
            reserved: header.reserved,
            payloadLength: vmBinary.length),
        vmBinary = vmBinary;

  factory UpgradeVmRequest.fromBuffer(ByteBuffer buffer) {
    var header = new RequestHeader.fromBuffer(buffer);
    if (header.command != RequestHeader.UPGRADE_VM) {
      throw new MessageDecodeException(
          'Invalid UpgradeVmRequest: ${buffer.asUint8List()}');
    }
    // TODO(wibling): figure out how to best represent the vm binary data.
    // The below has issues since the list view is offset and hence using
    // the underlying buffer requires the user to know the buffer is not the
    // same length as the list.
    var vmBinary = buffer.asUint8List(RequestHeader.HEADER_SIZE);
    return new UpgradeVmRequest.withHeader(header, vmBinary);
  }

  ByteBuffer toBuffer() {
    var bytes =
        new Uint8List(RequestHeader.HEADER_SIZE + vmBinary.length);
    _writeHeader(bytes.buffer);
    // TODO(wibling): This does a copy of the vm binary. Try to avoid that.
    for (int i = 0; i < vmBinary.length; ++i) {
      bytes[RequestHeader.HEADER_SIZE + i] = vmBinary[i];
    }
    return bytes.buffer;
  }
}

class FletchVersionRequest extends RequestHeader {
  FletchVersionRequest()
      : super(RequestHeader.FLETCH_VERSION);

  FletchVersionRequest.withHeader(RequestHeader header)
      : super(
            RequestHeader.FLETCH_VERSION,
            version: header.version,
            id: header.id,
            reserved: header.reserved);

  factory FletchVersionRequest.fromBuffer(ByteBuffer buffer) {
    var header = new RequestHeader.fromBuffer(buffer);
    if (header.command != RequestHeader.FLETCH_VERSION ||
        header.payloadLength != 0) {
      throw new MessageDecodeException(
          'Invalid FletchVersionRequest: ${buffer.asUint8List()}');
    }
    return new FletchVersionRequest.withHeader(header);
  }

  // A FletchVersionRequest has no payload so just use parent's toBuffer method.
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
  static const int HEADER_SIZE = 8;

  final int id;
  final int result;
  final int payloadLength;

  ReplyHeader(this.id, this.result, {this.payloadLength: 0});

  factory ReplyHeader.fromBuffer(ByteBuffer buffer) {
    if (buffer == null || buffer.lengthInBytes < HEADER_SIZE) {
      throw new MessageDecodeException(
          'Insufficient data for a ReplyHeader: ${buffer.asUint8List()}');
    }
    var id = readUint16(buffer, 0);
    var result = readUint16(buffer, 2);
    var payloadLength = readUint32(buffer, 4);
    return new ReplyHeader(id, result, payloadLength: payloadLength);
  }

  ByteBuffer toBuffer() {
    var buffer = new Uint8List(HEADER_SIZE).buffer;
    _writeHeader(buffer);
    return buffer;
  }

  void _writeHeader(ByteBuffer buffer) {
    writeUint16(buffer, 0, id);
    writeUint16(buffer, 2, result);
    writeUint32(buffer, 4, payloadLength);
  }
}

class StartVmReply extends ReplyHeader {
  final int vmId;
  final int vmPort;

  StartVmReply(int id, int result, {this.vmId, this.vmPort})
      : super(
            id,
            result,
            payloadLength: result == ReplyHeader.SUCCESS ? 4 : 0);

  factory StartVmReply.fromBuffer(ByteBuffer buffer) {
    var header = new ReplyHeader.fromBuffer(buffer);
    int vmId;
    int vmPort;
    if (header.result == ReplyHeader.SUCCESS) {
      // There must be 4 bytes of payload.
      if (buffer.lengthInBytes < ReplyHeader.HEADER_SIZE + 4 ||
          header.payloadLength != 4) {
        throw new MessageDecodeException(
            "Invalid StartVmReply: ${buffer.asUint8List()}");
      }
      vmId = readUint16(buffer, ReplyHeader.HEADER_SIZE);
      vmPort = readUint16(buffer, ReplyHeader.HEADER_SIZE + 2);
    }
    return new StartVmReply(
        header.id, header.result, vmId: vmId, vmPort: vmPort);
  }

  ByteBuffer toBuffer() {
    ByteBuffer buffer;
    if (result == ReplyHeader.SUCCESS) {
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE + 4).buffer;
      _writeHeader(buffer);
      writeUint16(buffer, ReplyHeader.HEADER_SIZE, vmId);
      writeUint16(buffer, ReplyHeader.HEADER_SIZE + 2, vmPort);
    } else {
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE).buffer;
      _writeHeader(buffer);
    }
    return buffer;
  }
}

class StopVmReply extends ReplyHeader {
  StopVmReply(int id, int result) : super(id, result);

  factory StopVmReply.fromBuffer(ByteBuffer buffer) {
    // The STOP_VM reply has no payload, just parse the header and return.
    return new ReplyHeader.fromBuffer(buffer);
  }

  // The STOP_VM reply has no payload, so leverage parent's toBuffer method.
}

class ListVmsReply extends ReplyHeader {
  final List<int> vmIds;

  ListVmsReply(int id, int result, {List<int> vmIds})
      : super(id, result, payloadLength: vmIds != null ? vmIds.length * 2 : 0),
        vmIds = vmIds;

  factory ListVmsReply.fromBuffer(ByteBuffer buffer) {
    var header = new ReplyHeader.fromBuffer(buffer);
    List<int> vmIds = [];
    if (header.result == ReplyHeader.SUCCESS) {
      for (int i = 0; i < header.payloadLength ~/ 2; ++i) {
        vmIds.add(readUint16(buffer, ReplyHeader.HEADER_SIZE + (i * 2)));
      }
    }
    return new ListVmsReply(header.id, header.result, vmIds: vmIds);
  }

  ByteBuffer toBuffer() {
    ByteBuffer buffer;
    if (result == ReplyHeader.SUCCESS) {
      int numVms = vmIds != null ? vmIds.length : 0;
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE + (numVms * 2)).buffer;
      _writeHeader(buffer);
      for (int i = 0; i < numVms; ++i) {
        writeUint16(buffer, ReplyHeader.HEADER_SIZE + (i * 2), vmIds[i]);
      }
    } else {
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE).buffer;
      _writeHeader(buffer);
    }
    return buffer;
  }
}

class UpgradeVmReply extends ReplyHeader {

  UpgradeVmReply(int id, int result) : super(id, result);

  factory UpgradeVmReply.fromBuffer(ByteBuffer buffer) {
    // The UPGRADE_VM reply has no payload, just parse the header and return.
    return new ReplyHeader.fromBuffer(buffer);
  }

  // The UPGRADE_VM reply has no payload, so leverage parent's toBuffer method.
}

class FletchVersionReply extends ReplyHeader {
  final int fletchVersion;

  FletchVersionReply(int id, int result, {this.fletchVersion})
      : super(id, result, payloadLength: result == ReplyHeader.SUCCESS ? 4 : 0);

  factory FletchVersionReply.fromBuffer(ByteBuffer buffer) {
    var header = new ReplyHeader.fromBuffer(buffer);
    int fletchVersion;
    if (header.result == ReplyHeader.SUCCESS) {
      // There must be 4 bytes of payload.
      if (buffer.lengthInBytes < ReplyHeader.HEADER_SIZE + 4 ||
          header.payloadLength != 4) {
        throw new MessageDecodeException(
            "Invalid FletchVersionReply: ${buffer.asUint8List()}");
      }
      fletchVersion = readUint32(buffer, ReplyHeader.HEADER_SIZE);
    }
    return new FletchVersionReply(
        header.id, header.result, fletchVersion: fletchVersion);
  }

  ByteBuffer toBuffer() {
    ByteBuffer buffer;
    if (result == ReplyHeader.SUCCESS) {
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE + 4).buffer;
      _writeHeader(buffer);
      writeUint32(buffer, ReplyHeader.HEADER_SIZE, fletchVersion);
    } else {
      buffer = new Uint8List(ReplyHeader.HEADER_SIZE).buffer;
      _writeHeader(buffer);
    }
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

class MessageDecodeException implements Exception {
  final String message;
  MessageDecodeException(this.message);
  String toString() => 'MessageDecodeException($message)';
}
