// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library tests.fletchc.incremental.common;

export 'dart:async' show
    Future;

export 'feature_test.dart' show
    NoArgFuture;

export 'program_result.dart' show
    EncodedResult;

import 'dart:async' show
    Future;

import 'dart:isolate' show
    ReceivePort;

import 'feature_test.dart' show
    NoArgFuture;

import 'program_result.dart' show
    EncodedResult,
    computeTests;

import 'tests_with_expectations.dart' as tests_with_expectations;

abstract class IncrementalTestSuite {
  final String suiteName;

  static final Map<String, EncodedResult> allTests =
      computeTests(tests_with_expectations.tests);

  const IncrementalTestSuite(this.suiteName);

  Future<Map<String, NoArgFuture>> list() {
    return new Future<Map<String, NoArgFuture>>.value(listSync());
  }

  Map<String, NoArgFuture> listSync() {
    Map<String, NoArgFuture> result = <String, NoArgFuture>{};
    allTests.forEach((String testName, EncodedResult encodedResult) {
      result["incremental/$suiteName/$testName"] =
          () => run(testName, encodedResult);
    });
    return result;
  }

  Future<Null> run(String testName, EncodedResult encodedResult);

  Future<Null> runFromMain(List<String> arguments) {
    Map<String, NoArgFuture> tests = listSync();
    if (arguments.isEmpty) {
      arguments = tests.keys.toList();
    }
    List<String> missingTests = <String>[];
    List<NoArgFuture> testsToRun = <NoArgFuture>[];
    for (String testName in arguments) {
      if (testName.startsWith("$suiteName/")) {
        testName = "incremental/$testName";
      } else if (!testName.startsWith("incremental/$suiteName/")) {
        testName = "incremental/$suiteName/$testName";
      }
      NoArgFuture testClosure = tests[testName];
      if (testClosure == null) {
        missingTests.add(testName);
      } else {
        testsToRun.add(testClosure);
      }
    }
    if (missingTests.isNotEmpty) {
      throw "The following tests couldn't be found: ${missingTests.join(' ')}";
    }
    Iterator testIterator = testsToRun.iterator;
    if (testIterator.moveNext()) {
      // Create a ReceivePort to ensure the Dart VM doesn't exit before all
      // futures have completed.
      ReceivePort done = new ReceivePort();
      return Future.doWhile(() async {
        await (testIterator.current)();
        return testIterator.moveNext();
      }).whenComplete(() {
        // The test is done, the Dart VM may exit. So we close the port.
        done.close();
      });
    } else {
      // This can't happen.
      throw "No tests specified.";
    }
  }
}
