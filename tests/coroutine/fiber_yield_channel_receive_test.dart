// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that fibers that are blocked in a receive on a channel wake up
// when there are messages on that channel.

import 'dart:dartino';

import 'package:isolate/isolate.dart';

main() {
  var channel = new Channel();
  var initPort = new Port(channel);
  var isolate = Isolate.spawn(() => worker(initPort));
  var port = channel.receive();
  for (int i = 0; i < 10; i++) {
    port.send(1);
  }
  port.send(0);
  isolate.join();
}

worker(Port port) {
  var channel = new Channel();
  port.send(new Port(channel));
  bool running = true;
  Fiber.fork(() {
    while (running) {
      Fiber.yield();
    }
  });
  while (running) {
    var msg = channel.receive();
    if (msg == 0) running = false;
    Fiber.yield();
  }
}
