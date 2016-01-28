// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  var a;
  var b;
  var c;

  A(this.b) {
    a = "hov ";
  }

  toString() => a + b;
}

main() {
  var a = new A("hej");
  a.c = 9;
  Expect.equals("hov hej", a.toString());
  Expect.equals(9, a.c);
}

