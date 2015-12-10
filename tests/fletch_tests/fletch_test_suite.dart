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
    UTF8;

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
    IsolatePool,
    ManagedIsolate;

import 'package:fletchc/src/driver/developer.dart' show
    configFileUri;

import 'package:fletchc/src/console_print.dart' show
    printToConsole;

import 'messages.dart' show
    Info,
    InternalErrorMessage,
    ListTests,
    ListTestsReply,
    Message,
    NamedMessage,
    RunTest,
    TestFailed,
    TestPassed,
    TestStdoutLine,
    TimedOut,
    messageTransformer;

import 'all_tests.dart' show
    NoArgFuture,
    TESTS;

// TODO(ahe): Should be: "@@@STEP_FAILURE@@@".
const String BUILDBOT_MARKER = "@@@STEP_WARNINGS@@@";

Map<String, NoArgFuture> expandedTests;

Sink<Message> messageSink;

main() async {
  int port = const int.fromEnvironment("test.fletch_test_suite.port");
  Socket socket = await Socket.connect(InternetAddress.LOOPBACK_IP_V4, port);
  messageSink = new SocketSink(socket);
  IsolatePool pool = new IsolatePool(isolateMain);
  Set<ManagedIsolate> isolates = new Set<ManagedIsolate>();
  Map<String, RunningTest> runningTests = <String, RunningTest>{};
  try {
    Stream<Message> messages = utf8Lines(socket).transform(messageTransformer);
    await for (Message message in messages) {
      if (message is TimedOut) {
        handleTimeout(message, runningTests);
        continue;
      }
      ManagedIsolate isolate = await pool.getIsolate();
      isolates.add(isolate);
      runInIsolate(
          isolate.beginSession(), isolate, message, runningTests);
    }
  } catch (error, stackTrace) {
    new InternalErrorMessage('$error', '$stackTrace').addTo(socket);
  }
  for (ManagedIsolate isolate in isolates) {
    isolate.port.send(null);
  }
  await socket.close();
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
    messageSink.add(message);
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
    ReceivePort port,
    ManagedIsolate isolate,
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
    do {
      if (iterator.current == null) {
        iterator.cancel();
        continue;
      }
      messageSink.add(iterator.current);
    } while (await iterator.moveNext());
    runningTests.remove(name);
    isolate.endSession();
  }).catchError((error, stackTrace) {
    messageSink.add(new InternalErrorMessage('$error', '$stackTrace'));
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
  messageSink = new PortSink(sendPort);
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
  sendPort.send(null); // Ask the main isolate to stop listening.
  receivePort.close();
  messageSink = null;
}

Future<Message> runTest(String name, NoArgFuture test) async {
  Directory tmpdir;

  printLineOnStdout(String line) {
    if (messageSink != null) {
      messageSink.add(new TestStdoutLine(name, line));
    } else {
      stdout.writeln(line);
    }
  }

  Future setupGlobalStateForTesting() async {
    tmpdir = await Directory.systemTemp.createTemp("fletch_test_home");
    configFileUri = tmpdir.uri.resolve('.fletch');
    printToConsole = printLineOnStdout;
  }

  Future resetGlobalStateAfterTesting() async {
    try {
      await tmpdir.delete(recursive: true);
    } on FileSystemException catch (e) {
      printToConsole('Error when deleting $tmpdir: $e');
    }
    printToConsole = Zone.ROOT.print;
  }

  if (test == null) {
    throw "No such test: $name";
  }
  await setupGlobalStateForTesting();
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
  } finally {
    await resetGlobalStateAfterTesting();
  }
  return new TestPassed(name);
}

Stream<String> utf8Lines(Stream<List<int>> stream) {
  return stream.transform(UTF8.decoder).transform(new LineSplitter());
}

void print(object) {
  if (messageSink != null) {
    messageSink.add(new Info('$object'));
  } else {
    stdout.writeln('$object');
  }
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

class SocketSink implements Sink<Message> {
  final Socket socket;

  SocketSink(this.socket);

  void add(Message message) {
    message.addTo(socket);
  }

  void close() {
    throw "not supported";
  }
}

class PortSink implements Sink<Message> {
  final SendPort port;

  PortSink(this.port);

  void add(Message message) {
    port.send(message);
  }

  void close() {
    throw "not supported";
  }
}
