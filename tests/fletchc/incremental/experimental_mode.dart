// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library tests.fletchc.incremental.experimental_mode;

import 'feature_test.dart' show
    compileAndRun;

import 'package:fletchc/incremental/fletchc_incremental.dart' show
    IncrementalMode;

import 'common.dart';

class ExperimentalModeTestSuite extends IncrementalTestSuite {
  const ExperimentalModeTestSuite()
      : super("experimental");

  Future<Null> run(String testName, EncodedResult encodedResult) {
    return compileAndRun(
        testName, encodedResult, incrementalMode: IncrementalMode.experimental);
  }
}

const ExperimentalModeTestSuite suite = const ExperimentalModeTestSuite();

/// Invoked by ../../fletch_tests/fletch_test_suite.dart.
Future<Map<String, NoArgFuture>> list() => suite.list();

Future<Null> main(List<String> arguments) => suite.runFromMain(arguments);
