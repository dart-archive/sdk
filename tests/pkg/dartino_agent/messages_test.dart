// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:dartino_agent/messages.dart';

void main() {
  testStartVmRequest();
  testStopVmRequest();
  testListVmsRequest();
  testUpgradeAgentRequest();
  testDartinoVersionRequest();

  testStartVmReply();
  testStopVmReply();
  testListVmsReply();
  testUpgradeAgentReply();
  testDartinoVersionReply();
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

void testUpgradeAgentRequest() {
  var request = new UpgradeAgentRequest([1, 2, 3]);
  var buffer = request.toBuffer();
  request = new UpgradeAgentRequest.fromBuffer(buffer);
  Expect.listEquals([1, 2, 3], request.binary);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(
      () => new UpgradeAgentRequest.fromBuffer(buffer));
}

void testDartinoVersionRequest() {
  var request = new DartinoVersionRequest();
  var buffer = request.toBuffer();
  request = new DartinoVersionRequest.fromBuffer(buffer);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(
      () => new DartinoVersionRequest.fromBuffer(buffer));
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

testUpgradeAgentReply() {
  var reply = new UpgradeAgentReply(123, ReplyHeader.SUCCESS);
  var buffer = reply.toBuffer();
  reply = new UpgradeAgentReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new UpgradeAgentReply.fromBuffer(buffer));
}

testDartinoVersionReply() {
  var reply =
      new DartinoVersionReply(123, ReplyHeader.SUCCESS, version: "456");
  var buffer = reply.toBuffer();
  reply = new DartinoVersionReply.fromBuffer(buffer);
  Expect.equals(123, reply.id);
  Expect.equals(ReplyHeader.SUCCESS, reply.result);
  Expect.equals("456", reply.dartinoVersion);

  buffer = new Uint8List.fromList([1, 2, 3]).buffer;
  throwsMessageDecodeException(() => new DartinoVersionReply.fromBuffer(buffer));
}
