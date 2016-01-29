// Copyright (c) 2013, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "package:expect/expect.dart";

class A {
  var _x;
  A(x) : _x = x {
    Expect.equals(x, _x);
  }
}

class B extends A {
  var _a;
  var _b;
  B(a): super(a), _a = a++ {
    Expect.equals(a, _a + 1);
  }
}

main() {
  var o = new B(3);
  Expect.equals(3, o._a);
  Expect.equals(null, o._b);
  Expect.equals(3, o._x);
  o = new A(3);
  Expect.equals(3, o._x);
}

