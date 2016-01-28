// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';
import 'package:isolate/process_runner.dart';

int fib(n) {
  if (n <= 2) return n;
  return fib(n - 1) + fib(n - 2);
}

void run() {
  fib(12);
}

void main() {
  withProcessRunner((runner) {
    for (int i = 0; i < 4000; i++) {
      runner.run(run);
    }
  });
}
