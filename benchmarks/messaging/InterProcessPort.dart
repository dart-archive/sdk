// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import '../BenchmarkBase.dart';
import 'utils.dart';

void main() {
  new InterProcessPortBenchmark().report();
}

class InterProcessPortBenchmark extends BenchmarkBase {
  Channel input;
  Port output;

  InterProcessPortBenchmark() : super("InterProcessPort");

  void setup() {
    input = new Channel();
    var port = new Port(input);
    Process.spawnDetached(() => portResponder(port));
    output = input.receive();
  }

  void exercise() => run();

  void run() {
    int i = DEFAULT_MESSAGES;
    while (i > 0) {
      output.send(i);
      i = input.receive();
    }
  }

  void teardown() {
    output.send(0);
  }
}
