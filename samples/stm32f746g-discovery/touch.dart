// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/ts.dart';

main() {
  run(new STM32F746GDiscovery());
}

void run(STM32F746GDiscovery board) {
  var display = board.frameBuffer;
  var surface = board.touchScreen;

  drawMark(int x, int y, int offsetX, int offsetY) {
    display
      ..drawLine(x, y - 5, x, y + 5, Color.blue)
      ..drawLine(x - 5, y, x + 5, y, Color.blue)
      ..writeText(x + offsetX, y + offsetY, "$x, $y");
  }

  display.backgroundColor = Color.white;
  display.clear();
  drawMark(25, 25, 3, 3);
  drawMark(display.width - 25, 25, -50, 3);
  drawMark(display.width - 25, display.height - 25, -58, -12);
  drawMark(25, display.height - 25, 3, -12);

  const radius = 20;
  const colors = const [
    Color.blue,
    Color.green,
    Color.red,
    Color.cyan,
    Color.magenta
  ];

  while (true) {
    TouchState t = surface.state;
    for (int index = 0; index < t.count; ++index) {
      int x = t.x[index];
      int y = t.y[index];
      if (x - radius > 0 &&
          x + radius < display.width &&
          y - radius > 0 &&
          y + radius < display.height) {
        display.drawCircle(x, y, radius, colors[index]);
      }
    }
    sleep(20);
  }
}
