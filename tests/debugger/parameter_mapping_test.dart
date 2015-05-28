// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Regression test for issue where regenerating the code when collecting debug
// information did not produce the same code because parameter mapping stubs
// were not cached.

f(int a, {int b: 1}) => a + b;

main() {
  f(1);
}
