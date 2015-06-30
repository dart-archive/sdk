// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  Expect.equals(1, fib(1));
  Expect.equals(1, fib(2));
  Expect.equals(2, fib(3));
  Expect.equals(144, fib(12));
  Expect.equals(75025, fib(25));
}

int fib(n) {
  if (n <= 2) return 1;
  return new Coroutine(fib)(n - 1)
       + new Coroutine(fib)(n - 2);
}
