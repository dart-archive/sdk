// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library static_test;

var a;

main() {
  setA("foo");
  _printString(a);
}

void setA(x) {
  a = x;
}

_printString(String s) native;
