// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  A(this.y, int w) : this.w = w;
  var x = 8;
  var y;
  var w;
}

class B extends A {
  var z = 0;
  B() : super(5, 42);
}

main() {
  A a = new B();
  Expect.equals(8, a.x);
  Expect.equals(5, a.y);
  Expect.equals(0, a.z);
  Expect.equals(42, a.w);
}



