// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:isolate/isolate.dart';
import 'package:expect/expect.dart';

void main() {
  Expect.equals(5, Isolate.spawn(simple).join());

  Expect.equals(3, Isolate.spawn(() => increment(2)).join());
  Expect.equals(5, Isolate.spawn(() => increment(4)).join());

  Expect.equals(4 - 1, (() => difference(4, 1))());
  Expect.equals(4 - 2, Isolate.spawn(() => difference(4, 2)).join());
  Expect.equals(4 - 3, Isolate.spawn(() => difference(4, 3)).join());

  // Ensure all failures inside the isolate result in an exception.
  Expect.throws(() => Isolate.spawn(() => Process.exit()).join());
  Expect.throws(() => Isolate.spawn(() => compileTimeError()).join());
  Expect.throws(() => Isolate.spawn(() => throwError()).join());
}

simple() {
  return 5;
}

increment(n) {
  return n + 1;
}

difference(x, y) {
  return x - y;
}

compileTimeError() {
  a b c;
}

throwError() {
  throw 'error';
}
