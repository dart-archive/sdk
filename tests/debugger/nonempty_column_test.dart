// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful breakpoint when breaking on a non-empty
// column that does not point to the first sub-expression of the line.

// FletchDebuggerCommands=bf tests/debugger/nonempty_column_test.dart 13 22,r,bt,c

int foo() {
  int x = 2;
  int y = 3;
  int z = (y + 4) - (x + 5);
  return x + y + z;
}

main() {
  return foo() - 5;
}
