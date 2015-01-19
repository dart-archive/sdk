// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class C {
  final t;
  final x;
  C([this.t, this.x = 3]);
}

class B extends C {
  B([x = 2]) : super(x);
}

class A {
  a(x, [y = 3]) {
    Expect.equals(1, x);
    return y;
  }
  b([x = 1, y = 2, z = 3]) {
    Expect.equals(1, x);
    Expect.equals(2, y);
    Expect.equals(3, z);
  }
}

foo(x, [y = 3]) {
  Expect.equals(1, x);
  return y;
}


void main() {
  Expect.equals(3, foo(1));
  Expect.equals(2, foo(1, 2));
  var a = new A();
  Expect.equals(3, a.a(1));
  Expect.equals(2, a.a(1, 2));
  a.b(1, 2, 3);
  a.b();
  var b = new B();
  Expect.equals(2, b.t);
  Expect.equals(3, b.x);
}
