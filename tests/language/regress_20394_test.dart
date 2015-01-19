// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'regress_20394_lib.dart';

class M {}

class C extends Super with M {
  C() : super._private(42);   /// 01: compile-time error
}

main() {
  new C();
}
