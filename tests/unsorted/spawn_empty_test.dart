// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

void run2() {
}

void run1() {
  // TODO(kasperl): Ideally, we should be able to
  // run with close to 500,000 processes even on
  // a 32-bit machine with 2GB of available address
  // space. Right now, we get close to that but
  // not quite close enough (~150,000). Note that ASan
  // also introduces quite an overhead.
  for (int i = 0; i < 150; i++) {
    Process.spawnDetached(run2);
  }
}

void main() {
  for (int i = 0; i < 1000; i++) {
    Process.spawnDetached(run1);
  }
}
