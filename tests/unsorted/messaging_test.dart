// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  Expect.equals(10, Fiber.fork(() => testDeliver(10)).join());
  Expect.equals(42, Fiber.fork(() => testDeliver(42)).join());

  Expect.equals(10, Fiber.fork(() => testSend(10)).join());
  Expect.equals(42, Fiber.fork(() => testSend(42)).join());
}

testDeliver(n) {
  Channel channel = new Channel();
  Fiber other = Fiber.fork(() {
    for (int i = 0; i < n; i++) channel.deliver(i);
  });

  int received = 0;
  for (int i = 0; i < n; i++) {
    Expect.equals(i, channel.receive());
    received++;
  }
  Expect.isNull(other.join());
  return received;
}

testSend(n) {
  Channel channel = new Channel();
  Fiber other = Fiber.fork(() {
    for (int i = 0; i < n; i++) {
      channel.send(i);
      Fiber.yield();
    }
  });

  int received = 0;
  int split = n ~/ 2;
  for (int i = 0; i < split; i++) {
    Expect.equals(i, channel.receive());
    received++;
  }

  // We join the other fiber here, so we force it to
  // enqueue all the remaining messages.
  Expect.isNull(other.join());

  for (int i = split; i < n; i++) {
    Expect.equals(i, channel.receive());
    received++;
  }
  return received;
}
