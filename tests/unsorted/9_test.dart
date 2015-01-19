// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

var topLevel1;
var topLevel2 = 2;

class A {
  static var a;
  A() {
    Expect.equals(4, a);
    a = 5;
  }

  static y() {
    return "test";
  }
}

main() {
  Expect.equals(2, topLevel2);
  topLevel1 = topLevel2 = 21;
  Expect.equals(42, (topLevel1 + topLevel2));

  A.a = 4;
  new A();
  Expect.equals(5, A.a);
  Expect.equals("test", A.y());
}


