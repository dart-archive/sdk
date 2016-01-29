// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// debugger_interrupt in interactive_debugger_tests.dart.
// Test that we can interrupt the debugger while the program is running.

loop() {
  while (true);
}

main() {
  loop();
}
