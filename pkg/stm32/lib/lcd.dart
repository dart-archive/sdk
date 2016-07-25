// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.lcd;

import 'dart:dartino.ffi';

final _lcdHeight = new Ffi('lcd_height', Ffi.returnsInt32, []);
final _lcdWidth = new Ffi('lcd_width', Ffi.returnsInt32, []);
final _lcdClear = new Ffi('lcd_clear', Ffi.returnsVoid, [Ffi.int32]);
final _lcdReadPixel = new Ffi('lcd_read_pixel', Ffi.returnsInt32, 
  [Ffi.int32, Ffi.int32]);
final _lcdDrawPixel = new Ffi('lcd_draw_pixel', Ffi.returnsVoid,
  [Ffi.int32, Ffi.int32, Ffi.int32]);
final _lcdDrawLine = new Ffi('lcd_draw_line', Ffi.returnsVoid,
  [Ffi.int32, Ffi.int32, Ffi.int32, Ffi.int32]);
final _lcdDrawCircle = new Ffi('lcd_draw_circle', Ffi.returnsVoid,
  [Ffi.int32, Ffi.int32, Ffi.int32]);
final _lcdSetForegroundColor = new Ffi('lcd_set_foreground_color', 
  Ffi.returnsVoid, [Ffi.int32]);
final _lcdSetBackgroundColor = new Ffi('lcd_set_background_color',
  Ffi.returnsVoid, [Ffi.int32]);
final _lcdDisplayString = new Ffi('lcd_display_string',
  Ffi.returnsVoid, [Ffi.int32, Ffi.int32, Ffi.pointer, Ffi.int32]);

/// Color.
class Color {
  static const red = const Color(0xff, 0x00, 0x00);
  static const green = const Color(0x00, 0xff, 0x00);
  static const blue = const Color(0x00, 0x000, 0xff);
  static const black = const Color(0x00, 0x00, 0x00);
  static const white = const Color(0xff, 0xff, 0xff);
  static const cyan = const Color(0x00, 0xff, 0xff);
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
  factory Color.fromRgb8888(int rgb8888) {
    return new Color(
        (rgb8888 >> 16) & 0xff, (rgb8888 >> 8) & 0xff, rgb8888 & 0xff);
  }

  // RGB565
  int get rgb565 => ((r & 0xf8) << 8) | ((g & 0xfb) << 3) | ((b & 0xf8) >> 3);

  /// RGB8888. Always sets the alpha channel to 0xff.
  int get rgb8888 => 0xff000000 | (r << 16) | (g << 8) | b;

  String toString() => 'Color: R=$r, G=$g, B=$b';
}

/// Text alignment.
enum TextAlign {
  /// Align text to the left.
  left,
  /// Align text to the center.
  center,
  /// Align text to the right.
  right,
}

class FrameBuffer {
  int get height => _lcdHeight([]);
  int get width => _lcdWidth([]);

  Color _backgroundColor = Color.white;

  clear([Color color]) {
    color ??= _backgroundColor;
    _lcdClear([color.rgb8888]);
  }

  set backgroundColor(Color color) {
    _backgroundColor = color;
    _lcdSetBackgroundColor([color.rgb8888]);
  }

  set foregroundColor(Color color) {
    _lcdSetForegroundColor([color.rgb8888]);
  }

  Color readPixel(int x, int y) {
    return new Color.fromRgb8888(_lcdReadPixel([x, y]));
  }

  void drawPixel(int x, int y, [Color color = Color.white]) {
    _lcdDrawPixel([x, y, color.rgb8888]);
  }

  void drawLine(int x1, int y1, int x2, int y2, [Color color = Color.white]) {
    _lcdSetForegroundColor([color.rgb8888]);
    _lcdDrawLine([x1, y1, x2, y2]);
  }

  void drawCircle(int x, int y, int radius, [Color color = Color.white]) {
    _lcdSetForegroundColor([color.rgb8888]);
    _lcdDrawCircle([x, y, radius]);
  }

  void writeText(int x, int y, String text, {TextAlign align: TextAlign.left}) {
    var m = new ForeignMemory.fromStringAsUTF8(text);
    int alignMode;
    switch (align) {
      case TextAlign.left: alignMode = 3; break;
      case TextAlign.center: alignMode = 1; break;
      case TextAlign.right: alignMode = 2; break;
    }
    _lcdDisplayString([x, y, m, alignMode]);
    m.free();
  }
}
