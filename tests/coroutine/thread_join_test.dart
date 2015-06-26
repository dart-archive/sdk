// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

main() {
  testResult();
  testExit();
}

testResult() {
  Expect.equals(42, Thread.fork(() => 42).join());
  Expect.equals(87, Thread.fork(() => 87).join());

  Function newYielder(value) => () {
    Thread.yield();
    return value;
  };

  Expect.equals(42, Thread.fork(newYielder(42)).join());
  Expect.equals(87, Thread.fork(newYielder(87)).join());
}

testExit() {
  Expect.isNull(Thread.fork(() => Thread.exit()).join());
  Expect.equals(42, Thread.fork(() => Thread.exit(42)).join());
  Expect.equals(87, Thread.fork(() => Thread.exit(87)).join());

  Function newYielder(value) => () {
    Thread.yield();
    Thread.exit(value);
  };

  Expect.equals(42, Thread.fork(newYielder(42)).join());
  Expect.equals(87, Thread.fork(newYielder(87)).join());
}
