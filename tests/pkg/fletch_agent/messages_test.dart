// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:fletch_agent/messages.dart';

void main() {
  testStartVmRequest();
  testStopVmRequest();
  testListVmsRequest();
  testUpgradeVmRequest();
  testFletchVersionRequest();

  testStartVmReply();
  testStopVmReply();
  testListVmsReply();
  testUpgradeVmReply();
  testFletchVersionReply();
}

void throwsMessageDecodeException(Function f) {
  Expect.throws(f, (e) => e is MessageDecodeException);
}

void testStartVmRequest() {
  var request = new StartVmRequest();
  var buffer = request.toBuffer();
  request = new StartVmRequest.fromBuffer(buffer);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new StartVmRequest.fromBuffer(buffer));
}

void testStopVmRequest() {
  var request = new StopVmRequest(123);
  var buffer = request.toBuffer();
  request = new StopVmRequest.fromBuffer(buffer);
  Expect.equals(123, request.vmPid);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new StopVmRequest.fromBuffer(buffer));
}

void testListVmsRequest() {
  var request = new ListVmsRequest();
  var buffer = request.toBuffer();
  request = new ListVmsRequest.fromBuffer(buffer);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new ListVmsRequest.fromBuffer(buffer));
}

void testUpgradeVmRequest() {
  var request = new UpgradeVmRequest([1, 2, 3]);
  var buffer = request.toBuffer();
  request = new UpgradeVmRequest.fromBuffer(buffer);
  Expect.listEquals([1, 2, 3], request.vmBinary);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new UpgradeVmRequest.fromBuffer(buffer));
}

void testFletchVersionRequest() {
  var request = new FletchVersionRequest();
  var buffer = request.toBuffer();
  request = new FletchVersionRequest.fromBuffer(buffer);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(
      () => new FletchVersionRequest.fromBuffer(buffer));
}

void testStartVmReply() {
  var reply =
      new StartVmReply(123, ReplyHeader.SUCCESS, vmId: 456, vmPort: 789);
  var buffer = reply.toBuffer();
  var x = buffer.asUint8List();
  reply = new StartVmReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);
  Expect.equals(456, reply.vmId);
  Expect.equals(789, reply.vmPort);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new StartVmReply.fromBuffer(buffer));
}

void testStopVmReply() {
  var reply = new StopVmReply(123, ReplyHeader.SUCCESS);
  var buffer = reply.toBuffer();
  reply = new StopVmReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new StopVmReply.fromBuffer(buffer));
}

testListVmsReply() {
  var reply = new ListVmsReply(123, ReplyHeader.SUCCESS, vmIds: [456, 789]);
  var buffer = reply.toBuffer();
  reply = new ListVmsReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);
  Expect.listEquals([456, 789], reply.vmIds);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new ListVmsReply.fromBuffer(buffer));
}

testUpgradeVmReply() {
  var reply = new UpgradeVmReply(123, ReplyHeader.SUCCESS);
  var buffer = reply.toBuffer();
  reply = new UpgradeVmReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new UpgradeVmReply.fromBuffer(buffer));
}

testFletchVersionReply() {
  var reply =
      new FletchVersionReply(123, ReplyHeader.SUCCESS, fletchVersion: 456);
  var buffer = reply.toBuffer();
  reply = new FletchVersionReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);
  Expect.equals(456, reply.fletchVersion);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new FletchVersionReply.fromBuffer(buffer));
}
