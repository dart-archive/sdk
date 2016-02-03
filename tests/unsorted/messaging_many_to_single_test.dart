// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

const int PROCESSES = 200000;

void main() {
  var channel = new Channel();
  var port = new Port(channel);
  Stopwatch watch = new Stopwatch()..start();
  for (int i = 0; i < PROCESSES; i++) {
    Process.spawnDetached(() => portResponder(port));
    Expect.equals(null, channel.receive());
  }
  print("Took ${watch.elapsedMicroseconds} us to start $PROCESSES process and"
        "sending one message.");
}

void portResponder(Port output) {
  output.send(null);
}
