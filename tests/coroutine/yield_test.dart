// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

main() {
  testReturn();
  testSingleYield();
  testMultipleYields();
}

testReturn() {
  var co = new Coroutine((x) => x);
  Expect.isTrue(co.isSuspended);
  Expect.equals(1, co(1));
  Expect.isTrue(co.isDone);

  co = new Coroutine((x) => x);
  Expect.equals(2, co(2));
}

testSingleYield() {
  var co = new Coroutine((x) => Coroutine.yield(x + 1));
  Expect.isTrue(co.isSuspended);
  Expect.equals(2, co(1));
  Expect.isTrue(co.isSuspended);
  Expect.equals(4, co(4));
  Expect.isTrue(co.isDone);
}

testMultipleYields() {
  var co;
  co = new Coroutine((x) {
    Expect.isTrue(co.isRunning);
    Expect.equals(1, x);
    Expect.equals(2, Coroutine.yield(4));
    Expect.isTrue(co.isRunning);
  });
  Expect.isTrue(co.isSuspended);
  Expect.equals(4, co(1));
  Expect.isTrue(co.isSuspended);
  Expect.isNull(co(2));
  Expect.isTrue(co.isDone);
}
