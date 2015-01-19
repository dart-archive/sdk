// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  A() {
  }

  a() {
    return 12;
  }
}

class B extends A {
  b() {
    return 42;
  }

  a(int x) {
  }
}

main() {
  A a = new B();
  Expect.equals(42, a.b());
  Expect.equals(12, a.a());
}


