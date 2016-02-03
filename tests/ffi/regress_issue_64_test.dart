// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino.ffi';
import "package:expect/expect.dart";

main() {
  Foreign memory = new ForeignMemory.allocated(8);
  var bigint = 9223372036854775806;
  memory.setInt64(0, bigint);
  Expect.equals(memory.getInt64(0), bigint);
  memory.setUint64(0, bigint);
  Expect.equals(memory.getUint64(0), bigint);
  memory.free();
}
