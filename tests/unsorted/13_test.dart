// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class B {
  const B();
}

class A {
  final a = "hej";
  final b = const B();
  final x;
  const A(this.x);
}

foo() => "string";
bar() => "string";

main() {
  const x = "x";
  Expect.isTrue(identical(x, x));
  Expect.isTrue(identical(const A(x), const A(x)));
  Expect.isFalse(identical(const A("x"), const A("y")));
  Expect.isTrue(identical(const A(1).a, const A(1).a));
  Expect.isTrue(identical(const A("x").b, const A("x").b));
  Expect.isTrue(identical(const A("x").x, const A("x").x));
  Expect.isTrue(identical(foo(), bar()));
}
