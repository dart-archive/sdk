// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

isolateFunction(channels) {
  var channel1 = channels[0];
  var channel2 = channels[1];
  channel1.send(5);
  Expect.equals(5.5, channel2.next);
  channel1.send(6);
  Expect.equals(6.5, channel2.next);
  channel1.send(7);
  Expect.equals(7.5, channel2.next);
}

void main() {
  var channel1 = new Channel();
  var channel2 = new Channel();
  var isolate = Isolate.spawn(isolateFunction, [channel1, channel2]);
  Expect.equals(5, channel1.next);
  channel2.send(5.5);
  Expect.equals(6, channel1.next);
  channel2.send(6.5);
  Expect.equals(7, channel1.next);
  channel2.send(7.5);
}


