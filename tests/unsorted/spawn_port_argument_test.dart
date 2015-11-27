// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  Channel channel = new Channel();
  final Port port = new Port(channel);
  Process.spawnDetached(() => run(port));
  int id = channel.receive();
  Expect.equals(port.id, id);
  Expect.equals(port.id, channel.receive().id);
  Expect.equals(null, channel.receive());
  Expect.equals(true, channel.receive());
  Expect.equals(false, channel.receive());
  Expect.equals("foo", channel.receive());
  Expect.equals(const Immutable(), channel.receive());
  Expect.equals(400000000000, channel.receive());
  Expect.equals(run, channel.receive());
  Expect.equals(0, channel.receive());
}

run(Port port) {
  Expect.isTrue(port != null);
  Expect.throws(() => port.send(new Mutable()), (e) => e is ArgumentError);
  port.send(port.id);
  port.send(port);
  port.send(null);
  port.send(true);
  port.send(false);
  port.send("foo");
  port.send(const Immutable());
  port.send(400000000000);
  port.send(run);
  port.send(0);
}

class Immutable {
  const Immutable();
}

class Mutable {
  var bar;
}
