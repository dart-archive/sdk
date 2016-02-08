// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino.ffi';
import 'dart:math';

class FrameBuffer {
  final ForeignPointer _surface;

  static ForeignFunction _getFrameBuffer =
      ForeignLibrary.main.lookup('gfx_create');
  static ForeignFunction _getWidth =
      ForeignLibrary.main.lookup('gfx_width');
  static ForeignFunction _getHeight =
      ForeignLibrary.main.lookup('gfx_height');
  static ForeignFunction _clear =
      ForeignLibrary.main.lookup('gfx_clear');
  static ForeignFunction _flush =
      ForeignLibrary.main.lookup('gfx_flush');
  static ForeignFunction _pixel =
      ForeignLibrary.main.lookup('gfx_pixel');

  int get width => _getWidth.icall$1(_surface);
  int get height => _getHeight.icall$1(_surface);

  FrameBuffer() : _surface = _getFrameBuffer.pcall$0();

  clear() => _clear.vcall$1(_surface);

  flush() => _flush.vcall$1(_surface);

  drawPixel(int x, int y, int color) => _pixel.vcall$4(_surface, x, y, color);

  /*
   * Adapted from lines.c written by David Brackeen.
   * http://www.brackeen.com/home/vga/
   */
  drawLine(int x1, int y1, int x2, int y2, int color) {
    var dx = x2 - x1;
    var dy = y2 - y1;
    var dxabs = dx.abs();
    var dyabs = dy.abs();
    var dxsign = dx.sign;
    var dysign = dy.sign;
    var x = dyabs >> 1;
    var y = dxabs >> 1;
    var px = x1;
    var py = y1;

    if (dxabs >= dyabs) {
      for (var i = 0; i < dxabs; i++) {
        y += dyabs;
        if (y >= dxabs) {
          y -= dxabs;
          py += dysign;
        }
        px += dxsign;
        drawPixel(px, py, color);
      }
    } else {
      for (var i = 0; i < dyabs; i++) {
        x += dxabs;
        if (x >= dyabs) {
          x -= dyabs;
          px += dxsign;
        }
        py += dysign;
        drawPixel(px, py, color);
      }
    }
  }
}
