// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful list of processes.

// FletchDebuggerCommands=b resume,r,c

import 'dart:fletch';

Port spawnPaused(Channel channel) {
  var port = new Port(channel);
  Process.spawnDetached(() {
    var c = new Channel();
    port.send(new Port(c));
    c.receive();
  });
  return channel.receive();
}

void resume(Channel channel, Port port) {
  port.send(null);
}

main() {
  Channel channel = new Channel();
  Port p = spawnPaused(channel);
  resume(channel, p);
}
