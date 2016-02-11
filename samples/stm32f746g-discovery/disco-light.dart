// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:stm32f746g_disco/stm32f746g_disco.dart';
import 'package:stm32f746g_disco/lcd.dart';
import 'dart:math';

main() {
  // Initialize display, and get display dimensions.
  STM32F746GDiscovery discoBoard = new STM32F746GDiscovery();
  var display = discoBoard.frameBuffer;
  display.backgroundColor = Color.black;
  int w = display.width;
  int h = display.height;

  // Loop eternally drawing random lines.
  Random rnd = new Random(42);
  int lineCounter = 0;
  while (true) {
    // Render a line of random color from the centre to a random location.
    var color = new Color(rnd.nextInt(255), rnd.nextInt(255), rnd.nextInt(255));
    display.drawLine(w ~/ 2, h ~/ 2, rnd.nextInt(w), rnd.nextInt(h), color);

    // Every 100 lines, clear the display and update the counter.
    lineCounter += 1;
    if ((lineCounter % 100) == 0) {
      display.clear(Color.black);
      display.writeText(10, 10, 'Rendered $lineCounter lines');
    }
  }
}
