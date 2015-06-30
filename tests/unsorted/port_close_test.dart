// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  testClose();
  testClosedPort();
  testCloseAfterSend();
  testRemoteClose();
}

testClose() {
  Channel channel = new Channel();
  for (int i = 0; i < 100000; i++) {
    Port port = new Port(channel);
    port.close();
  }

  Port a = new Port(channel);
  Port b = new Port(channel);
  a.close();
  b.close();
}

testClosedPort() {
  Channel channel = new Channel();
  Port port = new Port(channel);
  port.close();
  Expect.throws(() => port.close(), (e) => e is StateError);
  Expect.throws(() => port.send(42), (e) => e is StateError);
}

testCloseAfterSend() {
  Channel channel = new Channel();
  Port port = new Port(channel);
  port.send(42);
  port.close();
  Expect.equals(42, channel.receive());
}

testRemoteClose() {
  Channel channel = new Channel();
  Port port = new Port(channel);
  Process.spawn(closePort, port);
  Port other = channel.receive();
  other.send(port);
  port.close();
}

void closePort(Port a) {
  Channel channel = new Channel();
  a.send(new Port(channel));
  Port b = channel.receive();
  Expect.isTrue(a.id == b.id);
  a.close();
  b.close();
}
