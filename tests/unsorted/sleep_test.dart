// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

void main() {
  // Sleep 200 ms.
  int ms = 200;
  Stopwatch stopwatch = new Stopwatch()..start();
  sleep(ms);
  int elapsed = stopwatch.elapsedMilliseconds;
  Expect.isTrue(elapsed >= ms, "$elapsed >= $ms");
}
