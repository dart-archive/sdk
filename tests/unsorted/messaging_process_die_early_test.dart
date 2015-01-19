// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

const int PROCESSES = 5000;
const int MESSAGES = 10;

void main() {
  for (int i = 0; i < PROCESSES; i++) {
    Process.spawn(processRun);
  }
}

void processRun() {
  Channel input = new Channel();
  Process.spawn(portReceiver, new Port(input));
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
