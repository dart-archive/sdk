// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.system;

_entry(int mainArity) {
  _printString("Hello, World");
  _halt(1);
}

_halt(int code) native;
_printString(String s) native;
