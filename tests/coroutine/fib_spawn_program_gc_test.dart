// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// FletchOptions=
// FletchOptions=-Xgc-on-delete

import 'package:expect/expect.dart';

main() {
  Expect.equals(144, fib(12));
}

noop() { }

int fib(n) {
  Process.spawn(noop);
  if (n <= 2) return 1;
  return new Coroutine(fib)(n - 1)
       + new Coroutine(fib)(n - 2);
}
