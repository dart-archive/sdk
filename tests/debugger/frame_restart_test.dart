// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=b breakHere,r,bt,f 5,restart,bt,f 11,restart,bt,d 0,f 3,restart

void breakHere() {}

void foo(int i) {
  print(i);
  if (i == 0) {
    breakHere();
  } else if (i > 5) {
    var local = i + 1;
    foo(i - 1);
  } else if (i > 3) {
    var local = i + 1;
    var local2 = i + 2;
    foo(i - 1);
  } else {
    foo(i - 1);
  }
}

void main() {
  foo(10);
}