// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

main() {
  var x1 = 1;
  var x2 = 2;
  Expect.equals(-1, -1 * x1);
  Expect.equals(-2, -1 * x2);
  Expect.equals(0x20000000, 0x20000000 * x1);
  Expect.equals(0x40000000, 0x20000000 * x2);
}
