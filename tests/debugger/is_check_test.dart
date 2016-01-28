// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class A {
  final int a = 42;
}

class B extends A {
  final int b = 32;
}

class C extends A {
  final bool isB;
  C(A a, A b) : isB = b is B {
    if (a is B) a.b;
  }
}

final A globalA = new B();
final bool isB = globalA is B;

main() {
  var a = new A();
  var b = new B();
  if (a is A) a.a;
  if (a is B) a.b;
  if (b is A) b.a;
  if (b is B) b.b;
  var c = new C(a, b);
  if (isB) globalA.a;
}
