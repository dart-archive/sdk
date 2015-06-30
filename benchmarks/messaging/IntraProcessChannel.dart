// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import '../BenchmarkBase.dart';
import 'utils.dart';

void main() {
  new IntraProcessChannelBenchmark().report();
}

class IntraProcessChannelBenchmark extends BenchmarkBase {
  Channel input;
  Channel output;

  IntraProcessChannelBenchmark() : super("IntraProcessChannel");

  void setup() {
    input = new Channel();
    Fiber.fork(() => channelResponder(input));
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
