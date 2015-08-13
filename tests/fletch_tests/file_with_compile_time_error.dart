// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// This file contains a compile-time error and wouldn't be able to analyze
/// without error. So it is put into a separate file that dart2js doesn't see.
library fletch_tests.file_with_compile_time_error;

import 'dart:isolate' show
    SendPort;

import 'zone_helper_tests.dart' show
    testCompileTimeErrorHelper;

methodWithCompileTimeError() {
  new new();
}

main(List<String> arguments, SendPort port) {
  testCompileTimeErrorHelper(port, methodWithCompileTimeError);
}
