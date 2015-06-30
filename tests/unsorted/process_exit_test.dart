// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  Expect.equals(42, run(createInt));
  Expect.equals("fisk", run(createString));

  var list = run(createList);
  Expect.equals(3, list.length);
  Expect.equals(1, list[0]);
  Expect.equals(2, list[1]);

  Expect.isTrue(list[2] is List);
  Expect.equals(2, list[2].length);
  Expect.equals(3, list[2][0]);
  Expect.equals(4, list[2][1]);

  var fn = run(createFunction);
  Expect.equals(3 - 2, fn(3, 2));
  Expect.equals(3 - 4, fn(3, 4));
  Expect.equals(5 - 2, fn(5, 2));
}

createInt() => 42;
createString() => "fisk";
createList() => [ 1, 2, [ 3, 4 ] ];
createFunction() => (x, y) => x - y;

// ----------------------------

run(fn) {
  Channel channel = new Channel();
  Process.spawn(helper, new Port(channel));
  channel.receive().send(fn);
  return channel.receive();
}

void helper(Port port) {
  Channel channel = new Channel();
  port.send(new Port(channel));
  var fn = channel.receive();
  Process.exit(value: fn(), to: port);
}
