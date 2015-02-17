// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.system;

_entry(int mainArity) {
  if (true) {
    if (false) {
    }
  } else {
  }
  while (false) {
    _printString("while");
  }
  do {
    _printString("do");
  } while (false);
  _yield(true);
}

void foo(x) {
}

external _yield(bool halt);
_printString(String s) native;
