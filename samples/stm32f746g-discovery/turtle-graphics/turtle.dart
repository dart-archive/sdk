// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This sample was inspired by the Dart Hilbert curve sample:
// https://github.com/daftspaniel/dart-Hilbertcurve/blob/master/web/turtle.dart

library turtle;
import 'package:stm32f746g_disco/lcd.dart';
import "dart:math";

class Turtle {
  FrameBuffer _display;
  int _x;
  int _y;
  int _direction = 90;
  Color penColor = Color.red;

  /// Create a new Turtle, and set initial location.
  Turtle(this._display, {xPosition: 0, yPosition: 0}) {
    _display.clear();
    _x = xPosition;
    _y = yPosition;
  }

  /// Move forward [distance] pixels in the current direction with the pen down.
  forward(int distance) {
    double r = _direction * (PI / 180.0);
    int dx = (distance * sin(r)).toInt();
    int dy = (distance * cos(r)).toInt();

    _display.drawLine(_x, _y, _x + dx, _y + dy, penColor);

    this._x += dx;
    this._y += dy;
  }

  // Private utility method used internally in this library.
  _turn(int degrees) {
    _direction += degrees;
    _direction = _direction % 360;
  }

  /// Turn left [degrees] degrees.
  turnLeft(int degrees) {
    _turn(degrees);
  }

  /// Turn right [degrees] degrees.
  turnRight(int degrees) {
    _turn(-degrees);
  }

  /// Move to [x, y] with the pen up.
  flyTo(int x, int y) {
    this._x = x;
    this._y = y;
  }
}
