// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we can refer relatively to a file from the debugger.
// See interactive_debugger_tests.dart for actual test.

foo() {
  return 42;
}

main() {
  foo();
}
