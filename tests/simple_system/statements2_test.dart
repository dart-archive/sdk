// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library statements2_test;

import 'dart:fletch_natives';

class A {
  void a() {
  }
}

var a;

main() {
  if (true) {
    if (false) {
      a.a(foo: true);
    }
  } else {
  }
  while (false) {
    printString("while");
  }
  do {
    printString("do");
  } while (false);
}

void foo(x) {
}
