// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Render Turtle graphics on a LCD screen. Uses the Turtle definition in
// turtle.dart.
//
// This sample was inspired by the Dart Hilbert curve sample:
// https://github.com/daftspaniel/dart-Hilbertcurve/blob/master/web/turtle.dart

import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/lcd.dart';

import 'turtle.dart' show Turtle;

main() {
  // Initialize display, and Turtle with initial location.
  STM32F746GDiscovery discoBoard = new STM32F746GDiscovery();
  Turtle t = new Turtle(discoBoard.frameBuffer, xPosition: 50, yPosition: 50);

  // Draw a triangle.
  for (int i = 0; i < 3; i++) {
    t.forward(20);
    t.turnRight(120);
  }

  // Draw a star.
  t.penColor = Color.blue;
  t.flyTo(50, 150);
  for (int i = 0; i < 36; i++) {
    t.forward(100);
    t.turnRight(170);
  }

  // Draw a 4th order Hilbert curve using a separate TurtleDriver class.
  t.penColor = Color.green;
  t.flyTo(250, 200);
  TurtleDriver td = new TurtleDriver(t);
  td.hilbert(10, 4);

  // Sleep.
  while (true) {}
}

class TurtleDriver {
  Turtle turtle;

  TurtleDriver(this.turtle);

  /// Draw an [order] deep Hilbert curve with [sideLength] long sides.
  void hilbert(int sideLength, int order) {
    _hilbertRecur(sideLength, order, 90);
  }

  void _hilbertRecur(int size, int order, int angle) {
    // A Hilbert curve of order 0 is empty.
    if (order == 0) return;

    // A Hilbert curve of order n consists of three Hilbert curves of order n-1
    // connected by three lines.
    turtle.turnLeft(angle);
    _hilbertRecur(size, order - 1, -angle);

    turtle.forward(size);
    turtle.turnRight(angle);
    _hilbertRecur(size, order - 1, angle);

    turtle.forward(size);
    _hilbertRecur(size, order - 1, angle);

    turtle.turnRight(angle);
    turtle.forward(size);
    _hilbertRecur(size, order - 1, -angle);
    turtle.turnLeft(angle);
  }
}
