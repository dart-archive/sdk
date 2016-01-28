// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class X {
  noSuchMethod(invocation) => 42;
}

main() {
  var x = new X();
  Expect.equals(87, x.y = 87);
  Expect.equals(99, x.y = 99);
}
