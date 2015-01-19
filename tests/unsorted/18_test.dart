// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  foo({a: 3, b: 4}) {
    Expect.equals(3, a);
    Expect.equals(4, b);
  }
}

foo({a: 1, b: 2}) {
  Expect.equals(1, a);
  Expect.equals(2, b);
}

void main() {
  var a = new A();
  a.foo();
  a.foo(a: 3);
  a.foo(b: 4);
  a.foo(a: 3, b: 4);
  a.foo(b: 4, a: 3);
  foo();
  foo(a: 1);
  foo(b: 2);
  foo(a: 1, b: 2);
  foo(b: 2, a: 1);
}
