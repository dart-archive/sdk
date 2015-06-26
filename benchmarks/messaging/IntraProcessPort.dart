// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import '../BenchmarkBase.dart';
import 'utils.dart';

void main() {
  new IntraProcessPortBenchmark().report();
}

class IntraProcessPortBenchmark extends BenchmarkBase {
  Channel input;
  Port output;

  IntraProcessPortBenchmark() : super("IntraProcessPort");

  void setup() {
    input = new Channel();
    var port = new Port(input);
    Thread.fork(() => portResponder(port));
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
