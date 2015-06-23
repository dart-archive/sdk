// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests of fletch_test_suite.dart.
library fletch_tests.self_tests;

import 'dart:async' show
    Completer,
    Future;

import 'dart:convert' show
    JSON;

import 'package:expect/expect.dart' show
    Expect;

import 'messages.dart';

import 'fletch_test_suite.dart' as suite show print;

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

/// Test that messages can be instantiated and printed.
Future testMessages() async {
  void testMessage(Message message) {
    String json = JSON.encode(message);
    Expect.stringEquals('$message', '${new Message.fromJson(json)}');
  }

  testMessage(const InternalErrorMessage("arg1", "arg2"));
  testMessage(const ListTests());
  testMessage(const ListTestsReply(const <String>[]));
  testMessage(const RunTest("arg1"));
  testMessage(const TimedOut("arg1"));
  testMessage(const TestFailed("arg1", "arg2", "arg3"));
  testMessage(const TestPassed("arg1"));
  testMessage(const Info("message"));
  testMessage(const TestStdoutLine("name", "line"));
}

/// Test print method.
Future testPrint() async {
  suite.print("Debug print from fletch_tests works.");
}
