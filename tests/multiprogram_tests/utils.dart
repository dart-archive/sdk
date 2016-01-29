// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library multiprogram_tests.utils;

import 'package:expect/expect.dart';

class Point {
  final double x;
  final double y;

  Point.mutable(this.x, this.y);
  const Point.immutable(this.x, this.y);

  static Point multiplyMutable(Point a, Point b) {
    return new Point.mutable(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
  }

  static Point multiplyImmutable(Point a, Point b) {
    return new Point.immutable(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
  }
}

generateMutableGarbage(Duration duration) {
  _generateGarbage(duration,
                   (x, y) => new Point.mutable(x, y),
                   Point.multiplyMutable);
}

generateImmutableGarbage(Duration duration) {
  _generateGarbage(duration,
                   (x, y) => new Point.immutable(x, y),
                   Point.multiplyImmutable);
}

_generateGarbage(Duration duration, constructor(x, y), multiply(x, y)) {
  var sw = new Stopwatch()..start();

  while (true) {
    var rotate90 = constructor(0.0, 1.0);
    var point = constructor(0.0, 0.0);
    for (int i = 0; i < 100; i++) {
      point = multiply(point, rotate90);
    }

    Expect.equals(0.0, point.x);
    Expect.equals(0.0, point.y);

    if (sw.elapsedMilliseconds >= duration.inMilliseconds) break;
  }
}

