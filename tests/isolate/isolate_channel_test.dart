// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

isolateFunction(channel) {
  channel.send(5);
  Expect.equals(5.5, channel.next);
  channel.send(6);
  Expect.equals(6.5, channel.next);
  channel.send(7);
}

void main() {
  var channel = new Channel();
  var isolate = Isolate.spawn(isolateFunction, channel);
  Expect.equals(5, channel.next);
  channel.send(5.5);
  Expect.equals(6, channel.next);
  channel.send(6.5);
  Expect.equals(7, channel.next);
}

