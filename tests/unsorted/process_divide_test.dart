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
  return parallel.map(fib)([x - 1, x - 2]).reduce((a, b) => a + b);
}

void testFib() {
  Expect.equals(55, fib(10));
}

main() {
  testInvalidArguments();
  testFib();
}

const Parallel parallel = const Parallel();

class Parallel implements Function {
  const Parallel();
  Iterable call(Iterable values) => values;
  Parallel map(fn(value)) => new _ParallelMap(this, fn);
}

class _ParallelMap extends Parallel {
  final Parallel _link;
  final Function _fn;
  const _ParallelMap(this._link, this._fn);

  Iterable call(Iterable values) {
    final Function fn = _fn;
    List fns = _link(values).map((final e) => () => fn(e)).toList();
    return Process.divide(_entry, fns);
  }

  static _entry(fn) => fn();
}
