// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we can set a breakpoint in the body of an anonymous function.

// DartinoDebuggerCommands=bf tests/debugger/break_in_anonymous_function_test.dart 12,r,c

import 'package:expect/expect.dart';

var foo = () {
  return 1 + 2 + 3;
};

main() {
  Expect.equals(6, foo());
}
