// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  int get a => 42;
}

class B extends A {
  void foo() {
    Expect.equals(42, a);
  }
}

main() {
  new B().foo();
}
