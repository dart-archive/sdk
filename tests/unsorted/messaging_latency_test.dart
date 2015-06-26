// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

const int MESSAGES = 100000;

void main() {
  testIntraprocessChannel();
  testIntraprocessPort();
  testInterprocess();
}

// -----------------------------------------------------------

void testIntraprocessChannel() {
  Channel input = new Channel();
  Fiber.fork(() => channelResponder(input));
  Channel output = input.receive();
  int i = MESSAGES;
  Stopwatch watch = new Stopwatch()..start();
  while (i >= 0) {
    output.send(i);
    i = input.receive();
  }
  watch.stop();
  printTiming("Intraprocess (channel) latency per message", watch);
}

// -----------------------------------------------------------

void testIntraprocessPort() {
  Channel input = new Channel();
  Port port = new Port(input);
  Fiber.fork(() => portResponder(port));
  Port output = input.receive();
  int i = MESSAGES;
  Stopwatch watch = new Stopwatch()..start();
  while (i >= 0) {
    output.send(i);
    i = input.receive();
  }
  watch.stop();
  printTiming("Intraprocess (port) latency per message", watch);
}

// -----------------------------------------------------------

void testInterprocess() {
  Channel channel = new Channel();
  Process.spawn(portResponder, new Port(channel));
  Port port = channel.receive();
  int i = MESSAGES;
  Stopwatch watch = new Stopwatch()..start();
  while (i >= 0) {
    port.send(i);
    i = channel.receive();
  }
  watch.stop();
  printTiming("Interprocess latency per message", watch);
}

// -----------------------------------------------------------

void channelResponder(Channel output) {
  Channel input = new Channel();
  output.send(input);
  int message;
  do {
    message = input.receive();
    output.send(message - 1);
  } while (message > 0);
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

// -----------------------------------------------------------

void printTiming(String banner, Stopwatch watch) {
  int tus = (watch.elapsedMicroseconds * 10) ~/ (2 * MESSAGES);
  int us = tus ~/ 10;
  int fraction = tus % 10;
  print('$banner: $us.$fraction us.');
}
