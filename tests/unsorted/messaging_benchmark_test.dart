// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

const int PROCESSES = 1000;
const int MESSAGES = 1000;

void main() {
  Transceiver child = new Transceiver.spawn(runChild);
  child.send(PROCESSES);
  for (int i = 0; i < MESSAGES; i++) child.send(i);
  child.send(-1);

  int result = child.receive();
  int expected = fib(20) + PROCESSES;
  Expect.equals(expected, result);
}

void runChild(Transceiver parent) {
  int n = parent.receive();
  Transceiver child;
  if (n != 0) {
    child = new Transceiver.spawn(runChild);
    child.send(n - 1);
  }

  int processed = 0;
  int message;
  do {
    message = parent.receive();
    if (child != null) child.send(message);
    processed++;
  } while (message != -1);

  Expect.equals(MESSAGES + 1, processed);
  if (child == null) {
    parent.send(fib(20));
  } else {
    int result = child.receive();
    parent.send(1 + result);
  }
}

int fib(n) {
  if (n <= 2) return n;
  return fib(n - 1) + fib(n - 2);
}


// ------------------------------------------------

class Transceiver {
  final Channel _input;
  final Port _output;
  Transceiver._internal(this._input, this._output);

  factory Transceiver.spawn(void entry(Transceiver parent)) {
    Channel parent = new Channel();
    Process.spawn(_setupChild, new Port(parent));
    Port port = parent.receive();
    port.send(entry);
    return new Transceiver._internal(parent, port);
  }

  receive() => _input.receive();
  void send(message) => _output.send(message);

  static void _setupChild(Port port) {
    Channel child = new Channel();
    port.send(new Port(child));
    Function entry = child.receive();
    entry(new Transceiver._internal(child, port));
  }
}
