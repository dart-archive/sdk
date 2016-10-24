// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

// Test that a sleep wakes up even if there is another isolate that is running
// in a tight loop.
// Regression test for https://github.com/dartino/sdk/issues/483

void main() {
  Process.spawn(() => loop());
  print("Sleeping");
  sleep(1000);
  print("Out of Sleep");
}

// This is run in a child process, so it automatically is killed when the main
// process exits.
void loop() {
  while (true) {}
}

