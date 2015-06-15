// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class A {
  String toString() => "A";
}

class B {
  String toString() => "B";
}

foo() => new A();
bar() => new B();
baz(s) => s.length;

main() {
  baz('${foo()} and ${bar()}');
}