// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Regression test for https://github.com/dartino/sdk/issues/393

// DartinoDebuggerCommands=b foo,r,p,q

foo(x) => x;

main() {
  foo(42);
}
