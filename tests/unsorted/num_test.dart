// Copyright (c) 2014, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// Dart test for testing resolving of dynamic and static calls.

import "package:expect/expect.dart";

main() {
  testEquality();
  testInheritance();
  testDiv();
  testIntDoubleConfusion();
}

buildLargeInteger() {
  var x = 1000000000;
  return x + x + x + x;
}

testInheritance() {
  Expect.isTrue(1 is int);
  Expect.isFalse(1 is double);

  Expect.isFalse(1.0 is int);
  Expect.isTrue(1.0 is double);

  // Large integer literals aren't supported yet.
  if (false) {
    Expect.isTrue(4000000000 is int);
    Expect.isFalse(4000000000 is double);
  }
}

testEquality() {
  var large = buildLargeInteger();
  Expect.equals(large, large);
  Expect.notEquals(large, 0);
  Expect.notEquals(large, 1.0);
}

testDiv() {
  var large = buildLargeInteger();
  Expect.equals(1000000000, large / 4);
  Expect.equals(1000000000, large / 4.0);
  Expect.equals(1000000000, large ~/ 4);
  Expect.equals(1000000000, large ~/ 4.0);
}

// Regression test for bug where 20 was treated as 2.0 if
// 2.0 is used in the same program.
testIntDoubleConfusion() {
  var x = 2.0;
  var y = 20;
  Expect.notEquals(x, y);
}
