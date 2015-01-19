// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  a([x]) {
    return x;
  }
}

void main() {
  var a = new A();
  var f = a.a;
  Expect.equals(null, f());
  Expect.equals(2, f(2));
}
