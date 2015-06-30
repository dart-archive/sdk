// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  Process.spawn(noarg);
  Process.spawn(noarg, null);
  Expect.throws(() => Process.spawn(noarg, 99), (e) => e is ArgumentError);

  Expect.throws(() => Process.spawn(arg), (e) => e is ArgumentError);
  Expect.throws(() => Process.spawn(arg, null), (e) => e is ArgumentError);
  Process.spawn(arg, 99);

  Process.spawn(arg0, 0);
  Process.spawn(arg42, 42);

  Process.spawn(arg87);
  Process.spawn(arg87, 87);

  Process.spawn(argFoo, 'foo');
}

void arg(arg) { }
void noarg() { }

void arg0(arg) => Expect.equals(0, arg);
void arg42(arg) => Expect.equals(42, arg);
void arg87([arg = 87]) => Expect.equals(87, arg);

void argFoo(arg) => Expect.equals('foo', arg);
