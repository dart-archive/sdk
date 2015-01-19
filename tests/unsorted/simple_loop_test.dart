// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

foo() => 42;

class C {
  bar() => 87;
}

main() {
  // For now, this just tests that we exercise
  // the new native interpreter.
  var o = new C();
  for (int i = 0; i < 1000; i++) {
    for (int j = 0; j < 10000; j++) {
      foo();
      o.bar();
    }
  }
}
