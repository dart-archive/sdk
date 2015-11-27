// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

bool inMain = false;

foo() {
  Expect.isFalse(inMain);
}

void main() {
  inMain = true;
  Process.spawnDetached(foo);
}
