// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

foo(int x, int y) {
  if (x == y) {
    return x;
  }
}

void main() {
  Expect.equals(null, foo(1, 2));
}
