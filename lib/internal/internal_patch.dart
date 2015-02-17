// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

const patch = "patch";

@patch
void printToConsole(String line) {
  _printString(line);
}

_printString(String s) native;
