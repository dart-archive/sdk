// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests of fletch_test_suite.dart.
library fletch_tests.self_tests;

import 'dart:async' show
    Completer,
    Future;

/// Test sleeps for 3 seconds.
Future testSleepForThreeSeconds() async {
  await new Future.delayed(const Duration(seconds: 3));
}

/// Always fails.
Future testAlwaysFails() async {
  throw "This test always fails.";
}

/// Never completes (should be skipped).
Future testNeverCompletes() => new Completer().future;
