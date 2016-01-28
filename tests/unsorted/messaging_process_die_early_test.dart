// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';
import 'package:isolate/process_runner.dart';

const int PROCESSES = 5000;
const int MESSAGES = 10;

void main() {
  withProcessRunner((runner) {
    for (int i = 0; i < PROCESSES; i++) {
      runner.run(processRun);
    }
  });
}

void processRun() {
  Channel input = new Channel();
  Port port = new Port(input);
  Process.spawnDetached(() => portReceiver(port));
  var output = input.receive();
  for (int i = 0; i < MESSAGES; i++) {
    output.send(i);
  }
}

void portReceiver(Port output) {
  Channel input = new Channel();
  output.send(new Port(input));
  for (int i = 0; i < MESSAGES ~/ 2; i++) {
    input.receive();
  }
}
