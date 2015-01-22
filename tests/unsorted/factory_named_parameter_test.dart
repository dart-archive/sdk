// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  int i;

  A(this.i);

  factory A.fromInt(i, { named: true }) {
    if (named) return new A(i + 1);
    return new A(i);
  }
}

main() {
  Expect.equals(1, new A.fromInt(0).i);
  Expect.equals(0, new A.fromInt(0, named: false).i);
}
