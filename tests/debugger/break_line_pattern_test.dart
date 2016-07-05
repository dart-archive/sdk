// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=bf tests/debugger/break_line_pattern_test.dart 17 x
// Testing using : instead of space as separator.
// DartinoDebuggerCommands=bf tests/debugger/break_line_pattern_test.dart:18:y
// DartinoDebuggerCommands=bf tests/debugger/break_line_pattern_test.dart:19:3
// DartinoDebuggerCommands=bf tests/debugger/break_line_pattern_test.dart:20
// DartinoDebuggerCommands=r,bt
// DartinoDebuggerCommands=c,bt
// DartinoDebuggerCommands=c,bt
// DartinoDebuggerCommands=c,bt
// DartinoDebuggerCommands=c

main() {
  var x = 10;
  var y = 20;
  var z = 30 + (x + 10) + (y + 20);
  return 0;
}
