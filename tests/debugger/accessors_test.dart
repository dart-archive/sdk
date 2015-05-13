// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class A {
  int _y;
  int x;
  A(this.x, this._y);
  int get y => _y;
  int set y(int value) => _y = value;
}

main() {
  var a = new A(40, 2);
  a.x + a.y;
  a.x = 10;
  a.y = 32;
}
