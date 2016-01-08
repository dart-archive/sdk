// Copyright (c) 2016, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';
import 'package:expect/expect.dart';

// Creating a Uint8List with a double as link should not crash the vm, it
// should throw an error.
void main() {
  var x = 32.0;
  Expect.throws(() => new Uint8List(x));
}
