// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful breakpoint when breaking on a non-empty
// column that does not point to the first sub-expression of the line.

// FletchDebuggerCommands=bf a.dart 5,r,bf b.dart 5,2,c,c

import "find_file_test/a/a.dart" as a_a;
import "find_file_test/a/b.dart" as a_b;
import "find_file_test/b/b.dart" as b_b;

int foo() {
  int x = a_a.a();
  int y = a_b.b();
  int z = b_b.b();
  return x + y + z;
}

main() {
  return foo() == 60 ? 0 : 1;
}
