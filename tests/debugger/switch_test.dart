// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

int foo(x) => x;

main() {
  var x = 32;
  switch (x) {
    case 0:
      var y = 57;
      foo(y);
      break;
    case 1:
      var y = 58;
      foo(y);
      break;
    case 32:
      var y = 42;
      foo(y);
      break;
  }
}
