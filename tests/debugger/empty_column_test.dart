// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful breakpoint when breaking on a whitespace
// column.

// FletchDebuggerCommands=bf tests/debugger/empty_column_test.dart 12 1,r,c

int foo() {
  int x = 2;
  int y = 3; // break here.
  return x + y;
}

main() {
  return foo() - 5;
}
