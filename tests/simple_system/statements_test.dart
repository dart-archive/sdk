// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library statements_test;

import 'dart:fletch_natives';

main() {
  var x = true;
  x = 4;
  if ("".isEmpty) {
    printString("isEmpty");
    if (x) {
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
