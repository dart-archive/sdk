// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

int add(x, y) => x + y;

class A {
  final int _x, _y;
  int _z;

  A(int x, int y) : _x = x, _y = y, _z = add(x, y) {
    initA(_x, _y, _z);
  }

  void initA(int a, int b, int c) {
    if (a == b) _z = a + c;
  }
}

class B extends A {
  final int _a;
  int sum;

  B(int a) : _a = add(a, a), super(a, a) {
    initB(_a, _x, _y, _z);
  }

  void initB(int a, int b, int c, int d) {
    sum = a + b + c + d;
  }
}

main() {
  new B(42);
}
