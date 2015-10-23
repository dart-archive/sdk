// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class C {
  set a(value) { }
  set b(value) { return; }
  set c(value) { return null; }
  set d(value) => null;
  set e(value) { try { return; } finally { } }
  set f(value) { try { return null; } finally { } }
}

main() {
  var c = new C();
  Expect.equals(42, c.a = 42);
  Expect.equals(42, c.b = 42);
  Expect.equals(42, c.c = 42);
  Expect.equals(42, c.d = 42);
  Expect.equals(42, c.e = 42);
  Expect.equals(42, c.f = 42);

  Expect.equals(87, c.a = 87);
  Expect.equals(87, c.b = 87);
  Expect.equals(87, c.c = 87);
  Expect.equals(87, c.d = 87);
  Expect.equals(87, c.e = 87);
  Expect.equals(87, c.f = 87);

  Expect.isNull(c.a = null);
  Expect.isNull(c.b = null);
  Expect.isNull(c.c = null);
  Expect.isNull(c.d = null);
  Expect.isNull(c.e = null);
  Expect.isNull(c.f = null);
}
