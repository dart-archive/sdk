// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:dartino';

import 'package:expect/expect.dart';

main() {
  Channel channel = new Channel();
  Port port = new Port(channel);
  Process.spawnDetached(() => run(port));
  int id = channel.receive();
  Expect.equals(port.id, id);
}

run(Port port) {
  Expect.isTrue(port != null);
  new Timer(const Duration(milliseconds: 100), () {
    port.send(port.id);
  });
}
