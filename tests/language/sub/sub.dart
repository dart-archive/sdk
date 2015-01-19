// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library sub;
import '../cyclic_import_test.dart';
import 'package:expect/expect.dart';

subMain() {
  Expect.equals(42, value);
}
