// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  var a = 42;
  var b = "I'm soooo A";
  var y;
  A(int x, this.y) {
    Expect.equals(5, x);
  }
  toString() => b;
  get z => 8;
}

main() {
  var a = new A(5, 7);
  Expect.equals("I'm soooo A", a.toString());
  Expect.equals(42, a.a);
  Expect.equals(7, a.y);
  Expect.equals(8, a.z);
}
