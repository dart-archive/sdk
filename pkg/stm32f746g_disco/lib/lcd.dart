// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.lcd;

import 'dart:fletch.ffi';

final _lcdHeight = ForeignLibrary.main.lookup('lcd_height');
final _lcdWidth = ForeignLibrary.main.lookup('lcd_width');
final _lcdClear = ForeignLibrary.main.lookup('lcd_clear');
final _lcdDrawLine = ForeignLibrary.main.lookup('lcd_draw_line');
final _lcdSetForegroundColor =
    ForeignLibrary.main.lookup('lcd_set_foreground_color');
final _lcdSetBackgroundColor =
    ForeignLibrary.main.lookup('lcd_set_background_color');
final _lcdDisplayString =
    ForeignLibrary.main.lookup('lcd_display_string');

/// Color.
class Color {
  static const red = const Color(0xff, 0x00, 0x00);
  static const green = const Color(0x00, 0xff, 0x00);
  static const blue = const Color(0x00, 0x000, 0xff);
  static const black = const Color(0x00, 0x00, 0x00);
  static const white = const Color(0xff, 0xff, 0xff);
  static const cyan = const Color(0x00ffff);
  static const magenta = const Color(0xff, 0x00, 0xff);
  static const yellow = const Color(0xff, 0xff, 0x00);
  static const lightBlue = const Color(0x80, 0x80, 0xff);
  static const lightGreen = const Color(0x80, 0xff, 0x80);
  static const lightRed = const Color(0xff, 0x80, 0x80);
  static const lightCyan = const Color(0x80, 0xff, 0xff);
  static const lightMagenta = const Color(0xff, 0x80, 0xff);
  static const lightYellow = const Color(0xff, 0xff, 0x80);
  static const darkBlue = const Color(0x00, 0x00, 0x80);
  static const darkGreen = const Color(0x00, 0x80, 0x00);
  static const darkRed = const Color(0x80, 0x0, 0x000);
  static const darkCyan = const Color(0x00, 0x80, 0x80);
  static const darkMagenta = const Color(0x80, 0x00, 0x80);
  static const darkYellow = const Color(0x80, 0x80, 0x00);
  static const lightGray= const Color(0xD3, 0xD3, 0xD3);
  static const gray = const Color(0x80, 0x80, 0x80);
  static const darkGray = const Color(0x40, 0x40, 0x40);
  static const brown = const Color(0xA5, 0x2A, 0x2A);
  static const orange = const Color(0xff, 0xA5, 0x00);

  final int r;
  final int g;
  final int b;

  const Color(this.r, this.g, this.b);

  // RGB565
  int get rgb565 => ((r & 0xf8) << 8) | ((g & 0xfb) << 3) | ((b & 0xf8) >> 3);

  /// RGB8888. Always sets the alpha channel to 0xff.
  int get rgb8888 => 0xff000000 | (r << 16) | (g << 8) | b;

  String toString() => 'Color: R=$r, G=$g, B=$b';
}

class FrameBuffer {
  int get height => _lcdHeight.icall$0();
  int get width => _lcdWidth.icall$0();

  clear([Color color = Color.black]) {
    _lcdClear.icall$1(color._rgb8888);
  }

  set foregroundColor(Color color) {
    _lcdSetForegroundColor.icall$1(color._rgb8888);
  }

  set backgroundColor(Color color) {
    _lcdSetBackgroundColor.icall$1(color._rgb8888);
  }

  void drawLine(int x1, int y1, int x2, int y2, [Color color = Color.white]) {
    _lcdSetForegroundColor.icall$1(color._rgb8888);
    _lcdDrawLine.icall$4(x1, y1, x2, y2);
  }

  void writeText(int x, int y, String text) {
    var m = new ForeignMemory.fromStringAsUTF8(text);
    _lcdDisplayString.icall$3(x, y, m);
    m.free();
  }
}
