// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  test(0, 0);

  test(0, 5);
  test(3, 5);

  test(5, 0);
  test(5, 3);

  test(5, 5);
}

test(x, y) {
  List result = [];
  Function newWriter(n, marker) => () {
    for (int i = 0; i < n; i++) {
      result.add(marker);
      Fiber.yield();
    }
  };

  Function xWriter = newWriter(x, "x");
  Function yWriter = newWriter(y, "y");

  Fiber other = Fiber.fork(xWriter);
  yWriter();
  other.join();

  Expect.equals(x + y, result.length);
  int xLeft = x;
  int yLeft = y;

  for (int i = 0; i < result.length; i++) {
    if (xLeft == 0 || (yLeft > 0 && i.isEven)) {
      Expect.equals("y", result[i]);
      yLeft--;
    } else {
      Expect.isTrue(yLeft == 0 || i.isOdd);
      Expect.equals("x", result[i]);
      xLeft--;
    }
  }

  Expect.equals(0, xLeft);
  Expect.equals(0, yLeft);
}
