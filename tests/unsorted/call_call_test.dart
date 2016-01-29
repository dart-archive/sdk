// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  foo() { }

  call() {
  }
}

void main(args) {
  var a = new A();

  // Test member.
  Expect.equals(a.foo, a.foo.call);
  Expect.equals(a.foo, a.foo.call.call.call.call);

  // Test special member 'call'.
  Expect.equals(a, a.call);
  Expect.equals(a.call, a.call.call);
  Expect.equals(a.call, a.call.call.call.call);

  void foo() {
  }

  // Test for closures as well.
  Expect.equals(foo, foo.call);
  Expect.equals(foo.call, foo.call.call);
  Expect.equals(foo.call, foo.call.call.call.call);
}
