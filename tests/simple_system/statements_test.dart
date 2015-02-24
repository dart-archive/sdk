// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library statements_test;

import 'dart:fletch_natives';

class A {
  A() {
  }

  bool foo() {
    return false;
  }
}

main() {
  var a = new A();
  var x = true;
  x = 4;
  if ("".isEmpty) {
    printString("isEmpty");
    if (x) {
    }
  } else {
  }
  while (a.foo()) {
    printString("while");
  }
  do {
    printString("do");
  } while (false);
}
