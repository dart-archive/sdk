// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=b,r,n,s,n,n,n,n,n,q

void recurse(int i) {
  if (i == 0) return;
  recurse(--i);
}

main() {
  recurse(10);
}

