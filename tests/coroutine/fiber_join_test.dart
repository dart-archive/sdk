// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  testResult();
  testExit();
}

testResult() {
  Expect.equals(42, Fiber.fork(() => 42).join());
  Expect.equals(87, Fiber.fork(() => 87).join());

  Function newYielder(value) => () {
    Fiber.yield();
    return value;
  };

  Expect.equals(42, Fiber.fork(newYielder(42)).join());
  Expect.equals(87, Fiber.fork(newYielder(87)).join());
}

testExit() {
  Expect.isNull(Fiber.fork(() => Fiber.exit()).join());
  Expect.equals(42, Fiber.fork(() => Fiber.exit(42)).join());
  Expect.equals(87, Fiber.fork(() => Fiber.exit(87)).join());

  Function newYielder(value) => () {
    Fiber.yield();
    Fiber.exit(value);
  };

  Expect.equals(42, Fiber.fork(newYielder(42)).join());
  Expect.equals(87, Fiber.fork(newYielder(87)).join());
}
