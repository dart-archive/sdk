// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

void main() {
  var x = 0;
l: if (true) {
    x = 1;
    break l;
    x = 2;
  } else {
    x = 3;
  }
  x += 1;
  Expect.equals(2, x);
}
