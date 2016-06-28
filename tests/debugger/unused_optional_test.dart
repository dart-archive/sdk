// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=b main,r,s,s,l,c

import 'package:expect/expect.dart';

main() {
  // The default value for third parameter is evaluated in another file.
  // Ensure that the debug-info for default values is recorded correctly.
  Expect.equals(1, 1);
}