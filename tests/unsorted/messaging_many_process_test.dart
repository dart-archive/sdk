// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

const int PROCESSES = 2000;
const int MESSAGES = 200;

void main() {
  var channels = new List(PROCESSES);
  Stopwatch watch = new Stopwatch()..start();
  for (int i = 0; i < PROCESSES; i++) {
    var channel = new Channel();
    channels[i] = channel;
    var port = new Port(channel);
    Process.spawnDetached(() => processRun(port));
  }
  for (int i = 0; i < PROCESSES; i++) {
    channels[i].receive();
  }
  print("Took ${watch.elapsedMicroseconds} us to run $PROCESSES process pairs "
        "each exchanging $MESSAGES messages.");
}

void processRun(Port result) {
  Channel input = new Channel();
  Port inputPort = new Port(input);
  Process.spawnDetached(() => portResponder(inputPort));
  var output = input.receive();
  int i = MESSAGES;
  while (i >= 0) {
    output.send(i);
    i = input.receive();
  }
  result.send(null);
}

void portResponder(Port output) {
  Channel input = new Channel();
  output.send(new Port(input));
  int message;
  do {
    message = input.receive();
    output.send(message - 1);
  } while (message > 0);
}
