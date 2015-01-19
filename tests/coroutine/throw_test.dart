// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

main() {
  test(42);
  test(87);
  test(null);
  test("Yes!");
  test(test);
}

test(exception) {
  testShallowThrow(exception);
  testDeepThrow(exception);
  testDeepNestedThrow(exception);
}

testShallowThrow(exception) {
  var co = new Coroutine((x) => throw x);
  Expect.throws(() => co(exception), (x) => identical(x, exception));
  Expect.isTrue(co.isDone);
}

testDeepThrow(exception) {
  throwInTheDeep(n, exception) {
    if (n == 0) throw exception;
    throwInTheDeep(n - 1, exception);
  }

  var co = new Coroutine((x) => throwInTheDeep(100, x));
  Expect.throws(() => co(exception), (x) => identical(x, exception));
  Expect.isTrue(co.isDone);
}

testDeepNestedThrow(exception) {
  throwInTheDeep(n, exception) {
    if (n == 0) throw exception;
    return (n % 4 == 0)
        ? new Coroutine((x) => throwInTheDeep(n - 1, x))(exception)
        : throwInTheDeep(n - 1, exception);
  }

  var co = new Coroutine((x) => throwInTheDeep(100, x));
  Expect.throws(() => co(exception), (x) => identical(x, exception));
  Expect.isTrue(co.isDone);
}
