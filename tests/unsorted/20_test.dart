// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  static int s = 3;

  int f = 2;
  A();
}


void main() {
  var i = 4;
  i += 5;
  Expect.equals(9, i);
  A.s += 4;
  Expect.equals(7, A.s);
  A a = new A();
  a.f += 1;
  Expect.equals(3, a.f);
}
