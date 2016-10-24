// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Ensure that stepping over an invoke, which will create a one-shot breakpoint,
// doesn't result in deleting a coinciding user breakpoint.

// DartinoDebuggerCommands=b,b foo,b main 5,r,n,c,q

foo() {
  return 1 + 2 + 3;
}

main() {
  foo();
  foo();
}
