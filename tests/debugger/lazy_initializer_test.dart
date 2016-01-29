// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

final A a1 = new A(1);
final A a2 = new A(1);

class A {
  int x;
  A(int x) : this.x = x;
}

main() {
  var x = 42;
  var z = a1.x + x + a2.x;
}
