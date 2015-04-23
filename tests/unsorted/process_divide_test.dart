// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class Mutable {
  int x;
}

// A simple entry that expects the argument to be a function taking 0 arguments.
entry(fn) => fn();

bool isArgumentError(o) => o is ArgumentError;

void testInvalidArguments() {
  Expect.throws(() => Process.divide(entry, [new Mutable()]),
                isArgumentError);
  Expect.throws(() => Process.divide(null, [null]),
                isArgumentError);
}

int fib(int x) {
  if (x <= 1) return x;
  var res = Process.divide(entry, [() => fib(x - 1), () => fib(x - 2)]);
  return res[0] + res[1];
}

void testFib() {
  Expect.equals(55, fib(10));
}

main() {
  testInvalidArguments();
  testFib();
}
