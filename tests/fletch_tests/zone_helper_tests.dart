// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests of 'package:fletchc/src/zone_helper.dart'.
library fletch_tests.zone_helper_tests;

import 'dart:async';

import 'dart:isolate';

import 'package:fletchc/src/zone_helper.dart';

import 'package:expect/expect.dart';

/// Test that runGuarded completes with an error.
testEarlyError() async {
  bool threw = false;
  try {
    await runGuarded(() {
      throw "Early error";
    }, handleLateError: (e, s) {
      throw "Broken";
    });
  } catch (e) {
    threw = true;
  }
  Expect.isTrue(threw);
}

/// Test that handleLateError is invoked if a late asynchronous error occurs.
testLateError() async {
  Completer completer = new Completer();
  bool threw = false;
  try {
    await runGuarded(() {
      new Future(() {
        throw "Late error";
      });
      return new Future.value(0);
    }, handleLateError: (e, s) {
      completer.complete(e);
    });
  } catch (e) {
    threw = true;
  }
  Expect.isFalse(threw);
  Expect.stringEquals("Late error", await completer.future);
}

/// Helper for [testUnhandledLateError].
testUnhandledLateErrorIsolate(_) async {
  bool threw = false;
  try {
    await runGuarded(() {
      new Future(() {
        throw "Late error";
      });
      return new Future.value(0);
    });
  } catch (e) {
    threw = true;
  }
  Expect.isFalse(threw);
}

/// Test that a late asynchronous error is passed to the parent zone if no
/// handleLateError is provided (the parent zone being Zone.ROOT).
testUnhandledLateError() async {
  Isolate isolate =
      await Isolate.spawn(testUnhandledLateErrorIsolate, null, paused: true);
  ReceivePort exitPort = new ReceivePort();
  ReceivePort errorPort = new ReceivePort();
  isolate
      ..addOnExitListener(exitPort.sendPort)
      ..setErrorsFatal(true)
      ..addErrorListener(errorPort.sendPort)
      ..resume(isolate.pauseCapability);
  bool errorPortListenWasCalled = false;
  await errorPort.listen((errorList) {
    errorPort.close();
    errorPortListenWasCalled = true;
    var lines = errorList[0].split("\n");
    if (lines.length > 1) {
      // Bug (not getting the correct error from the system).
      Expect.isTrue(lines[0].endsWith("Late error"));
    } else {
      Expect.stringEquals("Late error", errorList[0]);
    }
  }).asFuture();
  bool exitPortListenWasCalled = false;
  await exitPort.listen((message) {
    exitPortListenWasCalled = true;
    exitPort.close();
    Expect.isNull(message);
  }).asFuture();
  Expect.isTrue(errorPortListenWasCalled);
  Expect.isTrue(exitPortListenWasCalled);
  print("Test succeeded.");
}

/// Test that a bad test will fail, not crash the test runner.
testAlwaysFails() async {
  // TODO(ahe): Simplify this test. It will probably be enough to just throw in
  // a listen method.
  Isolate isolate =
      await Isolate.spawn(testUnhandledLateErrorIsolate, null, paused: true);
  ReceivePort exitPort = new ReceivePort();
  ReceivePort errorPort = new ReceivePort();
  isolate
      ..addOnExitListener(exitPort.sendPort)
      ..setErrorsFatal(true)
      ..addErrorListener(errorPort.sendPort)
      ..resume(isolate.pauseCapability);
  await errorPort.listen((errorList) {
    errorPort.close();
    var lines = errorList[0].split("\n");
    if (lines.length > 1) {
      // Bug (not getting the correct error from the system).
      Expect.isTrue(lines[0].endsWith("Late error"));
    } else {
      Expect.stringEquals("Late error", errorList[0]);
    }
  }).asFuture();
  await exitPort.listen((message) {
    exitPort.close();
    throw "BROKEN";
  }).asFuture();
}
