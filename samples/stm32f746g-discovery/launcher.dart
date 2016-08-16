// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:stm32/lcd.dart';
import 'package:stm32/stm32f746g_disco.dart';

import 'i2c/temp_and_pressure.dart' as temperature;
import 'lines.dart' as lines;
import 'touch.dart' as touch;
import 'weather-service.dart' as weather;
import 'knight-rider.dart' as leds;
import 'dart:dartino';

main() {
  var board = new STM32F746GDiscovery();
  var display = board.frameBuffer;
  var surface = board.touchScreen;

  int width = display.width - 80;
  int radius = 20;
  var buttons = <Button>[
    new Button(40, 40, width, radius, 'LEDs (Concurrent GPIO)', leds.run,
        fork: true),
    new Button(40, 90, width, radius, 'Lines', lines.run),
    new Button(40, 140, width, radius, 'Temperature (I2C)', temperature.run),
    new Button(40, 190, width, radius, 'Touch', touch.run),
    new Button(40, 240, width, radius, 'Weather (Network)', weather.run),
  ];

  display.clear(Color.lightBlue);
  buttons.forEach((b) => b.draw(display));
  while (true) {
    sleep(20); // Give other Fibers a chance to run
    var touch = surface.state;
    if (touch.count == 0) continue;
    // Wait until user stops touching before continuing
    while (surface.state.count > 0) sleep(20);
    // Find the button pressed and perform the action
    for (Button b in buttons) {
      if (b.contains(touch.x[0], touch.y[0])) {
        if (b.fork) {
          Fiber.fork(() => b.entryPoint(board));
        } else {
          board.frameBuffer
            ..foregroundColor = Color.black
            ..backgroundColor = Color.white
            ..clear();
          b.entryPoint(board);
        }
      }
    }
  }
}

typedef RunSample(STM32F746GDiscovery disco);

class Button {
  final int left;
  final int middle;
  final int width;
  final int radius;
  final String text;
  final RunSample entryPoint;
  final bool fork;

  Button(this.left, this.middle, this.width, this.radius, this.text,
      this.entryPoint,
      {this.fork: false});

  void draw(FrameBuffer display) {
    fillCircle(int x, int y, int radius, Color color) {
      for (int count = 1; count <= radius; ++count) {
        display.drawCircle(x, y, count, color);
      }
    }

    fillRectangle(int x, int y, int w, int h, Color color) {
      for (int count = 0; count < h; ++count) {
        display.drawLine(x, y + count, x + w, y + count, color);
      }
    }

    fillCircle(left, middle, radius, Color.darkBlue);
    fillRectangle(left, middle - radius, width, 2 * radius + 1, Color.darkBlue);
    fillCircle(left + width, middle, radius, Color.darkBlue);
    display
      ..foregroundColor = Color.white
      ..backgroundColor = Color.darkBlue
      ..writeText(left + radius, middle - 5, text);
  }

  /// Return true if the given coordinates reside inside the button
  bool contains(int x, int y) =>
      x >= left &&
      x <= left + width &&
      y >= middle - radius &&
      y <= middle + radius;
}
