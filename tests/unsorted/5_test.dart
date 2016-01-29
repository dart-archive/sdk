// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  foo() { return 42; }
  bar() { return 87; }
  dee() { return 12; }
}

class B {
  foo() { return this.dee(); }
  baz() { return hest; }
  operator +(num other) => 99;
}

main() {
  var a = new A();
  Expect.equals(42, a.foo());
  Expect.equals(87, a.bar());
  var b = new B();
  Expect.equals(12, b.foo());
}
