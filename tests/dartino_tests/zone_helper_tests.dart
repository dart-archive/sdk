// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Tests of 'package:dartino_compiler/src/zone_helper.dart'.
library dartino_tests.zone_helper_tests;

import 'dart:async';

import 'dart:isolate';

import 'package:dartino_compiler/src/zone_helper.dart';

import 'package:expect/expect.dart';

import 'dart:io' show
    Platform;

final Uri fileWithCompileTimeError =
    Uri.base.resolve("tests/dartino_tests/file_with_compile_time_error.dart");

/// Test that runGuarded completes with an error when a synchronous error is
/// thrown.
testEarlySyncError() {
  bool threw = false;
  return runGuarded(() {
    throw "Early error";
  }, handleLateError: (e, s) {
    throw "Broken";
  }).catchError((e) {
    Expect.stringEquals("Early error", e);
    threw = true;
  }).then((_) {
    Expect.isTrue(threw);
  });
}

/// Test that runGuarded completes with an error when an asynchronous error is
/// thrown.
testEarlyAsyncError() {
  bool threw = false;
  return runGuarded(() {
    return new Future.error("Early error");
  }, handleLateError: (e, s) {
    throw "Broken";
  }).catchError((e) {
    Expect.stringEquals("Early error", e);
    threw = true;
  }).then((_) {
    Expect.isTrue(threw);
  });
}

/// Test that handleLateError is invoked if a late asynchronous error occurs.
testLateError() {
  Completer completer = new Completer();
  bool threw = false;
  return runGuarded(() {
    new Future(() {
      throw "Late error";
    });
    return new Future.value(42);
  }, handleLateError: (e, s) {
    completer.complete(e);
  }).catchError((_) {
    threw = true;
  }).then((value) {
    Expect.isFalse(threw);
    Expect.equals(42, value);
    return completer.future;
  }).then((String value) {
    Expect.stringEquals("Late error", value);
  });
}

/// Helper for [testUnhandledLateError].
testUnhandledLateErrorIsolate(_) {
  bool threw = false;
  return runGuarded(() {
    new Future(() {
      throw "Late error";
    });
    return new Future.value(0);
  }).catchError((_) {
    threw = true;
  }).then((_) {
    Expect.isFalse(threw);
  });
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
      ..setErrorsFatal(false)
      ..addErrorListener(errorPort.sendPort);
  acknowledgeControlMessages(isolate, resume: isolate.pauseCapability);
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
    isolate.kill();
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
  await new Stream.fromIterable([null]).listen((_) {
    throw "BROKEN";
  }).asFuture();
}

testCompileTimeError() async {
  Isolate isolate;
  ReceivePort exitPort = new ReceivePort();
  ReceivePort errorPort = new ReceivePort();
  ReceivePort port = new ReceivePort();

  bool exited = false;
  bool hadError = false;
  var messageFromIsolate;

  Future exitFuture = exitPort.listen((_) {
    exited = true;
    exitPort.close();
    errorPort.close();
    port.close();
  }).asFuture();

  Future errorFuture = errorPort.listen((List message) {
    hadError = true;
    var error = message[0];
    var stackTrace = message[1];
    if (stackTrace != null) {
      print(stackTrace);
    }
  }).asFuture();

  Future portFuture = port.listen((message) {
    Expect.isNull(messageFromIsolate);
    messageFromIsolate = message;
    isolate.kill();
  }).asFuture();

  // The call to spawnUri will pick up the default .packages packages config.
  isolate = await Isolate.spawnUri(
      fileWithCompileTimeError, <String>[], port.sendPort, paused: true,
      checked: true);

  isolate.setErrorsFatal(true);
  isolate.addOnExitListener(exitPort.sendPort);
  isolate.addErrorListener(errorPort.sendPort);
  await acknowledgeControlMessages(isolate, resume: isolate.pauseCapability);
  await exitFuture;
  await errorFuture;
  await portFuture;
  Expect.isTrue(exited);
  Expect.isTrue(hadError);
  Expect.isNotNull(messageFromIsolate);

  print("Test passed, got message: $messageFromIsolate");

  // No-op call to let dart2js know this method is actually used.
  testCompileTimeErrorHelper(null, () {});
}

testCompileTimeErrorHelper(SendPort port, void methodWithCompileTimeError()) {
  return runGuarded(() {
    methodWithCompileTimeError();
  }).catchError((e, s) {
    port.send("Error in isolate: $e\nStack trace: $s");
  });
}
