// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Regression test for https://github.com/dart-lang/fletch/issues/393

// FletchDebuggerCommands=b foo,r,p,q

foo(x) => x;

main() {
  foo(42);
}
