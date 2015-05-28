// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Modify this file to include more tests.
library fletch_tests.all_tests;

import 'dart:async' show
    Completer,
    Future;

import 'self_tests.dart' as self;

import '../fletchc/incremental/feature_test.dart' as incremental;

typedef Future NoArgFuture();

/// Map of names to tests or collections of tests.
///
/// Regarding the entries of this map:
///
/// If the key does NOT end with '/*', it is considered a normal test case, and
/// the value is a closure that returns a future that completes as the test
/// completes. If the test fails, it should complete with an error.
///
/// Otherwise, if the key DOES end with '/*', it is considered a collection of
/// tests, and the value must be a closure that returns a `Future<Map<String,
/// NoArgFuture>>` consting of only normal test cases.
const Map<String, NoArgFuture> TESTS = const <String, NoArgFuture>{
  'self/testSleepForThreeSeconds': self.testSleepForThreeSeconds,
  'self/testAlwaysFails': self.testAlwaysFails,
  'self/testNeverCompletes': self.testNeverCompletes,

  'incremental/*': incremental.listTests,
};
