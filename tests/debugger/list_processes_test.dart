// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful list of processes.

// FletchDebuggerCommands=b resume,r,lp,c,lp,c

import 'dart:async';
import 'dart:fletch';
import 'package:expect/expect.dart';

Port spawnPaused(Channel channel, Channel monitor) {
  var port = new Port(channel);
  Process.spawnDetached(() {
      var c = new Channel();
      port.send(new Port(c));
      var echo = c.receive();  // B1
      port.send(echo);
    },
    monitor: new Port(monitor));
  return channel.receive();
}

void resume(Channel channel, Port port) {
  port.send(42);
  Expect.equals(42, channel.receive());
}

main() {
  Channel channel = new Channel();
  Channel monitor = new Channel();
  Port p1 = spawnPaused(channel, monitor);
  Port p2 = spawnPaused(channel, monitor);
  // Give the children time to block at B1.
  Timer timer = new Timer(const Duration(seconds: 2), () {
    resume(channel, p2);
    Expect.equals(DeathReason.Terminated, monitor.receive().reason);
    resume(channel, p1);
    Expect.equals(DeathReason.Terminated, monitor.receive().reason);
  });
}
