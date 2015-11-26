// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=bf tests/debugger/break_line_pattern_test.dart 10 x,r,c

main () {
  var x = 10;
  var y = 20;
  var z = 30 + (x + 10) + (y + 20);
  return 0;
}
