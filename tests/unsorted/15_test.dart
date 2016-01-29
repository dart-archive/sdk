// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class A {
  var a;
  A() : a = ["hej"];
}

void main() {
  A a = new A();
  a.a[0] = "dav";
  Expect.equals(1, a.a.length);
  Expect.equals("dav", a.a[0]);
}
