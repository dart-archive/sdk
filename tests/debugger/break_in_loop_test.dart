// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that a trivial loop has source code listing.

// DartinoDebuggerCommands=b loop,r,l,q

loop() {
  while (true);
}

main() {
  loop();
}
