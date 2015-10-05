// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';

import "package:expect/expect.dart";

final ForeignFunction magic_meat = ForeignLibrary.main.lookup('magic_meat');
final ForeignFunction magic_veg = ForeignLibrary.main.lookup('magic_veg');

main() {
  Expect.equals(0xbeef, magic_meat.icall$0());
  Expect.equals(0x1eaf, magic_veg.icall$0());
  Expect.throws(() => ForeignLibrary.main.lookup('i-am-not-here'));
  Expect.throws(() => ForeignLibrary.fromName("test.lib"));
}
