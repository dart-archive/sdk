// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=b main,r,n
// Enable view of internal frames.
// DartinoDebuggerCommands=toggle internal
// Step into an internal function (Random.nextInt)
// DartinoDebuggerCommands=s,s,s
// DartinoDebuggerCommands=bt,p
// Disable view of internal frames.
// DartinoDebuggerCommands=toggle internal
// Now we should get the stack view of the top current non-internal frame(main).
// DartinoDebuggerCommands=bt,p,p rnd
// DartinoDebuggerCommands=q

import 'dart:math';

main() {
  var rnd = new Random();
  rnd.nextInt(255);
}
