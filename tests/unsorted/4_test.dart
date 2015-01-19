// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

int fib(int n) {
  if (n <= 1) return 1;
  return fib(n - 1) + fib(n - 2);
}

void main() {
  Expect.equals(2178309, fib(31));
}
