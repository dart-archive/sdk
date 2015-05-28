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

import 'package:fletchc/src/driver/driver_main.dart' show
    IsolatePool;

import 'messages.dart';

import 'all_tests.dart' show
    NoArgFuture,
    TESTS;

Map<String, NoArgFuture> expandedTests;

main() async {
  IsolatePool pool = new IsolatePool(isolateMain);
  Set isolates = new Set();
  try {
    var messages = utf8Lines(stdin).transform(messageTransformer);
    await for (Message message in messages) {
      var isolate = await pool.getIsolate();
      isolates.add(isolate);
      var port = isolate.beginSession();
      runInIsolate(port, isolate, message);
    }
  } catch (error, stackTrace) {
    new InternalErrorMessage('$error', '$stackTrace').print();
  }
  for (var isolate in isolates) {
    isolate.port.send(null);
  }
}

runInIsolate(port, isolate, Message message) async {
  StreamIterator iterator = new StreamIterator(port);
  bool hasNext = await iterator.moveNext();
  assert(hasNext);
  SendPort sendPort = iterator.current;
  sendPort.send(message);
  hasNext = await iterator.moveNext();
  assert(hasNext);
  iterator.current.print();
  iterator.cancel();
  isolate.endSession();
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
  Completer completer = new Completer();
  StringBuffer sb = new StringBuffer();
  ZoneSpecification specification = new ZoneSpecification(
      print: (_1, _2, _3, String line) {
        sb.writeln(line);
      },
      handleUncaughtError: (_1, _2, _3, error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      });

  Zone.current.fork(specification: specification).runGuarded(test).then(
      completer.complete);

  try {
    await completer.future;
  } catch (error, stackTrace) {
    return new TestFailed(name, '$sb', '$error', '$stackTrace');
  }
  return new TestPassed(name, '$sb');
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
