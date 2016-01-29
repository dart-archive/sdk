// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library test.dart2js_hello_world;

import 'dart2js_helper.dart';

main() {
  compileUri(Uri.base.resolve('benchmarks/DeltaBlue.dart'));
}
