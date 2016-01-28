// Copyright (c) 2014, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// Dart test for testing resolving of dynamic and static calls.

import "package:expect/expect.dart";

class A {
  A(x) {
    Expect.equals(5, x);
  }

  A.named(x) {
    Expect.equals(7, x);
  }
}

class B extends A {
  B(x) : super(x + 2) {
    Expect.equals(3, x);
  }

  B.named(x) : super.named(x + 2) {
    Expect.equals(5, x);
  }
}

main() {
  new A(5);
  new A.named(7);
  new B(3);
  new B.named(5);
}

