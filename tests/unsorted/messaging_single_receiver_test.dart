// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

const int PROCESSES = 1000;
const int MESSAGES = 100;

void main() {
  Stopwatch watch = new Stopwatch()..start();
  var channel = new Channel();
  var port = new Port(channel);
  for (int i = 0; i < PROCESSES; i++) {
    Process.spawnDetached(() => processRun(port));
  }
  int done = 0;
  while (done < PROCESSES) {
    int i = channel.receive();
    if (i == 0) done ++;
  }
  print("Took ${watch.elapsedMicroseconds} us to run $PROCESSES processes with "
        "$MESSAGES messages.");
}

void processRun(Port output) {
  for (int i = MESSAGES; i >= 0; i--) {
    output.send(i);
  }
}
