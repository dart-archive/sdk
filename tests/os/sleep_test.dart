// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.os' as os;

import 'package:expect/expect.dart';

void main() {
  // Sleep 200 ms.
  int ms = 200;
  Stopwatch stopwatch = new Stopwatch()..start();
  os.sleep(ms);
  // There is a chance that it'll resume slightly early on some system, so we
  // just ensure that at least 50% of the time is spent sleeping.
  int elapsed = stopwatch.elapsedMilliseconds;
  Expect.isTrue(elapsed >= ms ~/ 2, "$elapsed >= ${ms ~/ 2}");
}
