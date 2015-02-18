// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.system;

class A {
  void a() {
  }
}

var a;

_entry(int mainArity) {
  if (true) {
    if (false) {
      a.a(foo: true);
    }
  } else {
  }
  while (false) {
    _printString("while");
  }
  do {
    _printString("do");
  } while (false);
  _halt(1);
}

void foo(x) {
}

_halt(int code) native;
_printString(String s) native;
