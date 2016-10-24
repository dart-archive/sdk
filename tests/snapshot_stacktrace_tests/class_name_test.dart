// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class A {
  var x, y, z;
  A(this.x, this.y, this.z);
}

class B {
  var a;
  B(this.a);
}

main() {
  throw new A(1, "foo", new B("bar"));
}