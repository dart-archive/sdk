// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Concurrency sample that uses Fibers to structure a program into several
// logical pieces:
//
//   1. A counter handler which prints a count.
//
//   2. A touch handler which prints a touch location.
//
//   3. A main program handler (in this sample left empty for simplicity).
//
// Illustrates the cooperative scheduling of fibers.
//
// For additional concurrency info, see https://dartino.org/guides/concurrency/
import 'dart:dartino';
import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/ts.dart';

var disco = new STM32F746GDiscovery();
var touchScreen = disco.touchScreen;
var display = disco.frameBuffer;

void main() {
  display.clear(Color.white);

  Fiber.fork(handleCounter);
  Fiber.fork(handleTouch);
  handleMain();
}

void handleMain() {
  while (true) {
    // Main doesn't do anything in this sample, so we just sleep.
    // This implicitely yields to the next Fiber.
    sleep(100);
  }
}

void handleCounter() {
  int i = 0;
  while (true) {
    // Update and print counter.
    i++;
    display.writeText(10, 20, 'Counter: $i');

    // Yield to the next Fiber.
    Fiber.yield();
  }
}

void handleTouch() {
  while (true) {
    // Read and print the touch location.
    TouchState t = touchScreen.state;
    if (t != null && t.count >= 1) {
      display.writeText(10, 50, 'Touch registered at ${t.x[0]}, ${t.y[0]}    ');
    }

    // Yield to the next Fiber.
    Fiber.yield();
  }
}
