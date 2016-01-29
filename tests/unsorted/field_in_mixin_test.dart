// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  int w = 4;
}

class B {
  int x = 2;
  int y = 7;
  int z = 6;
}

class C = Object with A;
class D extends C with B {
  baz() {
    Expect.equals(4, w);
    Expect.equals(7, x);
    Expect.equals(2, super.x);
    Expect.equals(6, super.z);
  }

  get x => super.y;
}


void main() {
  var c = new D();
  c.baz();
}
