// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.io' as io;

import 'package:expect/expect.dart';

void main() {
  // Sleep 200 ms.
  Stopwatch stopwatch = new Stopwatch()..start();
  io.sleep(200);
  Expect.isTrue(stopwatch.elapsedMilliseconds >= 200);
}
