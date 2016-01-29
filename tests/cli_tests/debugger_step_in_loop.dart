// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// debugger_step_in_loop in interactive_debugger_tests.dart.
// Test that we can use various step commands to step an infinite loop.

loop() {
  while (true);
}

main() {
  loop();
}
