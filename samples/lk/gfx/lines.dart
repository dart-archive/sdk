// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//

import 'package:lk/framebuffer.dart';

class MovingPoint {
  int x, y;
  int mx, my;

  MovingPoint(this.x, this.y, this.mx, this.my);

  update(FrameBuffer surface) {
    x += mx;
    if (x < 0 || x > surface.width) {
      mx = -mx;
      x += mx << 1;
    }
    y += my;
    if (y < 0 || y > surface.height) {
      my = -my;
      y += my << 1;
    }
  }
}

class MovingLine {
  MovingPoint a, b;
  int color;

  MovingLine(this.a, this.b, this.color);

  update(FrameBuffer surface) {
    a.update(surface);
    b.update(surface);
    surface.drawLine(a.x, a.y, b.x, b.y, color);
  }
}

main () {
  List lines = [];

  lines.add(new MovingLine(new MovingPoint(1,1,2,3),
      new MovingPoint(10, 10, 3, 2), 0xFFFF00FF));
  lines.add(new MovingLine(new MovingPoint(1,1,5,-2),
      new MovingPoint(10, 10, -2, 5), 0xFF0000FF));
  lines.add(new MovingLine(new MovingPoint(1,1,9,4),
      new MovingPoint(10, 10, 3, 8), 0xFFFF0000));
  lines.add(new MovingLine(new MovingPoint(1,1,-1,2),
      new MovingPoint(10, 10, 2, -1), 0xFF77FF33));
  lines.add(new MovingLine(new MovingPoint(1,1,1,-2),
      new MovingPoint(10, 20, -2, 1), 0xFF0033FF));
  lines.add(new MovingLine(new MovingPoint(1,1,-9,3),
      new MovingPoint(20, 10, 6, 8), 0xFF773399));
  lines.add(new MovingLine(new MovingPoint(1,1,7,-2),
      new MovingPoint(10, 1, -2, -3), 0xFF77FF00));

  var surface = new FrameBuffer();

  while (true) {
    for (int j = 0; j < 1000; j++) {
      lines.forEach((line) => line.update(surface));
      surface.flush();
    }
    surface.clear();
  }
}
