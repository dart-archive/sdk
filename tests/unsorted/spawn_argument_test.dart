// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';
import 'package:isolate/process_runner.dart';

main() {
  Expect.throws(() => Process.spawn(noarg, 99), (e) => e is ArgumentError);
  Expect.throws(() => Process.spawn(arg), (e) => e is ArgumentError);
  Expect.throws(() => Process.spawn(arg, null), (e) => e is ArgumentError);

  withProcessRunner((runner) {
    runner.run(() => noarg());
    runner.run(() => arg(99));

    runner.run(() => arg0(0));
    runner.run(() => arg42(42));

    runner.run(() => arg87());
    runner.run(() => arg87(87));

    runner.run(() => argFoo('foo'));
  });
}

void arg(arg) { }
void noarg() { }

void arg0(arg) => Expect.equals(0, arg);
void arg42(arg) => Expect.equals(42, arg);
void arg87([arg = 87]) => Expect.equals(87, arg);

void argFoo(arg) => Expect.equals('foo', arg);
