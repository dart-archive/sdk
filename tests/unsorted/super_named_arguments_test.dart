// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  int x;
  int y;
  int a;
  int b;

  A(this.x, this.y, {this.a: -1, this.b: -1}) {
  }
}

class B extends A {
  B(int x, int y) : super(x, y, b: 4, a: 3);
}

void main() {
  var b = new B(1, 2);
  Expect.equals(1, b.x);
  Expect.equals(2, b.y);
  Expect.equals(3, b.a);
  Expect.equals(4, b.b);
}
