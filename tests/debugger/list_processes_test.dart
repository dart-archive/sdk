// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful list of processes.

// FletchDebuggerCommands=b resume,r,lp,c,lp,c

import 'dart:fletch';

Port spawnPaused(Channel channel) {
  var port = new Port(channel);
  Process.spawnDetached(() {
    var c = new Channel();
    port.send(new Port(c));
    var echo = c.receive();
    port.send(echo);
  });
  return channel.receive();
}

void resume(Channel channel, Port port) {
  port.send(42);
  var result = channel.receive();
}

main() {
  Channel channel = new Channel();
  Port p1 = spawnPaused(channel);
  Port p2 = spawnPaused(channel);
  resume(channel, p2);
  resume(channel, p1);
}
