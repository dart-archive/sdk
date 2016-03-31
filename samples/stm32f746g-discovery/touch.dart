// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:stm32f746g_disco/lcd.dart';
import 'package:stm32f746g_disco/stm32f746g_disco.dart';
import 'package:stm32f746g_disco/ts.dart';

main() {
  var disco = new STM32F746GDiscovery();
  var frameBuffer = disco.frameBuffer;
  var touchScreen = disco.touchScreen;

  frameBuffer.backgroundColor = Color.white;
  frameBuffer.clear(Color.white);
  int x = 25;
  int y = 25;
  frameBuffer.drawLine(x, y - 5, x, y + 5, Color.blue);
  frameBuffer.drawLine(x - 5, y, x + 5, y, Color.blue);
  frameBuffer.writeText(x + 3, y + 3, "$x, $y");
  x = frameBuffer.width - 25;
  frameBuffer.drawLine(x, y - 5, x, y + 5, Color.blue);
  frameBuffer.drawLine(x - 5, y, x + 5, y, Color.blue);
  frameBuffer.writeText(x - 50, y + 3, "$x, $y");

  for (int count = 0; count < 50; ++count) {
    TouchState t = touchScreen.state;
    var msg = new StringBuffer('touch: ${t.count}');
    for (int index = 0; index < t.count; ++index) {
      msg.write(' - ${t.x[index]}, ${t.y[index]}');
    }
    print(msg);
    sleep(500);
  }
  print('frame: ${frameBuffer.width}, ${frameBuffer.height}');
}
