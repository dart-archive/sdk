// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that the VM does not crash when listing processes.  This targets a
// regression where we might not have paused all processes when stopped at a
// breakpoint. Not doing so could cause inconsistent process structures to be
// accessed.

import 'dart:fletch';

Port spawnChild(Channel channel) {
  var port = new Port(channel);
  Process.spawnDetached(() {
    var c = new Channel();
    port.send(new Port(c));
    // With varying delay, spawn grandchildren to affect process structures.
    for (int i = 0; i < 5000; ++i) {
      final m = i;
      Process.spawnDetached(() { for (int j = 0; j < m; ++j); });
      for (int k = 0; k < 1000; ++k);
    }
    c.receive();
    port.send(null);
  });
  return channel.receive();
}

void resumeChild(Channel channel, Port port) {
  port.send(null);
  channel.receive();
}

main() {
  Channel channel = new Channel();
  Port child1 = spawnChild(channel);
  Port child2 = spawnChild(channel);
  resumeChild(channel, child1);
  resumeChild(channel, child2);
}
