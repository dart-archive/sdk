// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Helper program for running unit tests in warmed-up Dart VMs.
///
/// This program listens for JSON encoded messages on stdin (one message per
/// line) and prints out messages in response (also in JSON, one per line).
///
/// Messages are defined in 'message.dart'.
library fletch_tests.fletch_test_suite;

import 'dart:core' hide print;

import 'dart:io';

import 'dart:convert' show
    JSON,
    LineSplitter,
    Utf8Decoder;

import 'dart:async' show
    Completer,
    Future,
    Stream,
    StreamIterator,
    Zone,
    ZoneSpecification;

import 'dart:isolate';

import 'package:fletchc/src/zone_helper.dart' show
    runGuarded;

import 'package:fletchc/src/driver/driver_main.dart' show
    IsolatePool;

import 'messages.dart';

import 'all_tests.dart' show
    NoArgFuture,
    TESTS;

// TODO(ahe): Should be: "@@@STEP_FAILURE@@@".
const String BUILDBOT_MARKER = "@@@STEP_WARNINGS@@@";

Map<String, NoArgFuture> expandedTests;

main() async {
  IsolatePool pool = new IsolatePool(isolateMain);
  Set isolates = new Set();
  Map<String, RunningTest> runningTests = <String, RunningTest>{};
  try {
    var messages = utf8Lines(stdin).transform(messageTransformer);
    await for (Message message in messages) {
      if (message is TimedOut) {
        handleTimeout(message, runningTests);
        continue;
      }
      var isolate = await pool.getIsolate();
      isolates.add(isolate);
      runInIsolate(
          isolate.beginSession(), isolate, message, runningTests);
    }
  } catch (error, stackTrace) {
    new InternalErrorMessage('$error', '$stackTrace').print();
  }
  for (var isolate in isolates) {
    isolate.port.send(null);
  }
}

class RunningTest {
  final cancelable;
  final isolate;
  RunningTest(this.cancelable, this.isolate);

  void kill() {
    cancelable.cancel();
    isolate.kill();
  }
}

void handleTimeout(TimedOut message, Map<String, RunningTest> runningTests) {
  RunningTest test = runningTests.remove(message.name);
  if (test != null) {
    test.kill();
    message.print();
  } else {
    // This can happen for two reasons:
    // 1. There's a bug, and test.dart will hang.
    // 2. The test terminated just about the same time that test.dart decided
    // it had timed out.
    // Case 2 is unlikely, as tests aren't normally supposed to run for too
    // long. Hopefully, case 1 is unlikely, but this message is helpful if
    // test.dart hangs.
    print("\nWarning: Unable to kill ${message.name}");
  }
}

void runInIsolate(
    port,
    isolate,
    Message message,
    Map<String, RunningTest> runningTests) {
  StreamIterator iterator = new StreamIterator(port);
  String name = message is NamedMessage ? message.name : null;

  if (name != null) {
    runningTests[name] = new RunningTest(iterator, isolate);
  }

  // The rest of this function is executed without "await" as we want tests to
  // run in parallel on multiple isolates.
  new Future<Null>(() async {
    bool hasNext = await iterator.moveNext();
    if (!hasNext && name != null) {
      // Timed out.
      assert(runningTests[name] == null);
      return null;
    }
    assert(hasNext);
    SendPort sendPort = iterator.current;
    sendPort.send(message);

    hasNext = await iterator.moveNext();
    if (!hasNext && name != null) {
      // Timed out.
      assert(runningTests[name] == null);
      return null;
    }
    assert(hasNext);
    runningTests.remove(name);
    iterator.current.print();
    iterator.cancel();
    isolate.endSession();
  }).catchError((error, stackTrace) {
    new InternalErrorMessage('$error', '$stackTrace').print();
  });
}

/* void */ isolateMain(SendPort port) async {
  expandedTests = await expandTests(TESTS);
  ReceivePort receivePort = new ReceivePort();
  port.send(receivePort.sendPort);
  port = null;
  await for (SendPort port in receivePort) {
    if (port == null) {
      receivePort.close();
      break;
    }
    ReceivePort clientPort = new ReceivePort();
    port.send(clientPort.sendPort);
    handleClient(port, clientPort);
  }
}

Future<Null> handleClient(SendPort sendPort, ReceivePort receivePort) async {
  Message message = await receivePort.first;
  Message reply;
  if (message is RunTest) {
    String name = message.name;
    reply = await runTest(name, expandedTests[name]);
  } else if (message is ListTests) {
    reply = new ListTestsReply(expandedTests.keys.toList());
  } else {
    reply =
        new InternalErrorMessage("Unhandled message: ${message.type}", null);
  }
  sendPort.send(reply);
  receivePort.close();
}

Future<Message> runTest(String name, NoArgFuture test) async {
  if (test == null) {
    throw "No such test: $name";
  }
  printLineOnStdout(String line) {
    new TestStdoutLine(name, line).print();
  }
  try {
    await runGuarded(
        test,
        printLineOnStdout: printLineOnStdout,
        handleLateError: (error, StackTrace stackTrace) {
      if (name == 'zone_helper/testAlwaysFails') {
        // This test always report a late error (to ensure the framework
        // handles it).
        return;
      }
      print(
          // Print one string to avoid interleaved messages.
          "\n$BUILDBOT_MARKER\nLate error in test '$name':\n"
          "$error\n$stackTrace");
    });
  } catch (error, stackTrace) {
    return new TestFailed(name, '$error', '$stackTrace');
  }
  return new TestPassed(name);
}

Stream<String> utf8Lines(Stream<List<int>> stream) {
  return stream.transform(new Utf8Decoder()).transform(new LineSplitter());
}

void print(object) {
  new Info('$object').print();
}

Future<Map<String, NoArgFuture>> expandTests(Map<String, NoArgFuture> tests) {
  Map<String, NoArgFuture> result = <String, NoArgFuture>{};
  var futures = [];
  tests.forEach((String name, NoArgFuture f) {
    if (name.endsWith("/*")) {
      var future = f().then((Map<String, NoArgFuture> tests) {
        tests.forEach((String name, NoArgFuture f) {
          result[name] = f;
        });
      });
      futures.add(future);
    } else {
      result[name] = f;
    }
  });
  return Future.wait(futures).then((_) => result);
}
