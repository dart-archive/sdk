// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

main() {
  testRecursion(0);
  testRecursion(10);
  testRecursion(100);
  testRecursion(1000);
}

void testRecursion(n) {
  var co = new Coroutine(recurse);
  Expect.isTrue(co.isSuspended);
  Expect.equals(42, co(n));
  Expect.equals(87, co(87));
  Expect.equals(99, co(42));
  Expect.isTrue(co.isDone);
}

int recurse(n) {
  if (n == 0) {
    Expect.equals(87, Coroutine.yield(42));
    Expect.equals(42, Coroutine.yield(87));
    return 99;
  } else {
    return recurse(n - 1);
  }
}
