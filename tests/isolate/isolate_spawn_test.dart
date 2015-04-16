// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:isolate/isolate.dart';
import 'package:expect/expect.dart';

void main() {
  Expect.equals(5, Isolate.spawn(simple).join());

  Expect.equals(3, Isolate.spawn(increment, 2).join());
  Expect.equals(5, Isolate.spawn(increment, 4).join());
}

simple() {
  return 5;
}

increment(n) {
  return n + 1;
}
