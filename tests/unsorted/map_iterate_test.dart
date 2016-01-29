// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

main() {
  var m = { 'x': 42, 'y': 87 };
  int count = 0;
  for (var k in m.keys) {
    Expect.notEquals(null, k);
    count++;
  }
  Expect.equals(2, count);
}
