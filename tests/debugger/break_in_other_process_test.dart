// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we can break at a breakpoint hit by another process than main.

// DartinoDebuggerCommands=b foo,r,bt,c

import 'dart:dartino';
import 'package:expect/expect.dart';

int foo() => 42;

other(Port port) {
  port.send(foo());
}

main() {
  var channel = new Channel();
  var port = new Port(channel);
  Process.spawnDetached(() { other(port); });
  Expect.equals(42, channel.receive());
}
