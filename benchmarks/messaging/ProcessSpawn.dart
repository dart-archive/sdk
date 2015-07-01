// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import '../BenchmarkBase.dart';
import 'utils.dart';

void main() {
  new ProcessSpawnBenchmark().report();
}

class ProcessSpawnBenchmark extends BenchmarkBase {
  Channel input;
  Port inputPort;

  ProcessSpawnBenchmark() : super("ProcessSpawn");

  void setup() {
    input = new Channel();
    inputPort = new Port(input);
  }

  void exercise() => run();

  void run() {
    int i = DEFAULT_MESSAGES;
    for (int i = 0; i < DEFAULT_MESSAGES; i++) {
      Process.spawn(processEntry, inputPort);
    }
    for (int i = 0; i < DEFAULT_MESSAGES; i++) {
      input.receive();
    }
  }

  static void processEntry(port) {
    port.send(null);
  }
}
