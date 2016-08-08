// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import 'package:dartino_compiler/src/hub/hub_main.dart';
import 'package:dartino_compiler/src/hub/session_manager.dart';
import 'package:dartino_compiler/src/verbs/create_verb.dart';
import 'package:dartino_compiler/src/worker/developer.dart';
import 'package:expect/expect.dart';

import 'message_tests.dart';

bool _debug = false;

/// This program exercises the `dartino x-complete` functionality
Future<Null> main() async {
  MockClientConnection client;

  // Tab complete - dartino
  client = await testComplete(['x-complete']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectCompletion(client.stdoutMessages, "create");
  expectCompletion(client.stdoutMessages, "show");

  // Tab complete - dartino
  client = await testComplete(['x-complete', 'dartino']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectCompletion(client.stdoutMessages, "create");
  expectCompletion(client.stdoutMessages, "show");

  // Tab complete - dartino
  client = await testComplete(['x-complete', 'dartino', '']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectCompletion(client.stdoutMessages, "create");
  expectCompletion(client.stdoutMessages, "show");

  // Tab complete - dartino cr
  client = await testComplete(['x-complete', 'cr']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectCompletion(client.stdoutMessages, "create");
  expectNoCompletion(client.stdoutMessages, "show");

  // Tab complete - dartino cr
  client = await testComplete(['x-complete', 'dartino', 'cr']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectCompletion(client.stdoutMessages, "create");
  expectNoCompletion(client.stdoutMessages, "show");

  if (_debug) print('... "dartino x-complete" test passed');
}

Future<MockClientConnection> testComplete(List<String> arguments) async {
  print("Command line: ${arguments.join(' ')}");
  MockClientConnection client = new MockClientConnection(debug: _debug);
  client.stdoutMessages = <String>[];
  client.parseArguments(null, null, false, arguments);

  String testName = 'x-complete-test';
  UserSession session =
      await createSession(testName, () => allocateWorker(pool));
  ClientVerbContext context = new ClientVerbContext(client, pool, session,
      initializer: new CreateSessionTask(testName, null, client.sentence.base));

  var exitCode = await runZoned(() {
    return client.sentence.performVerb(context);
  }, zoneSpecification: new ZoneSpecification(print: (_1, _2, _3, line) {
    client.printLineOnStdout(line);
  }), onError: (e, s) {
    Expect.fail('$e\n$s');
  });

  client.recordedExitCode = exitCode;
  endAllSessions();
  pool.shutdown();
  return client;
}

void expectCompletion(List<String> messages, String expected) {
  messages.firstWhere((msg) => msg == expected, orElse: () {
    Expect.fail('Failed to find "$expected" in $messages');
  });
}

void expectNoCompletion(List<String> messages, String expected) {
  var msg = messages.firstWhere((msg) => msg == expected, orElse: () => null);
  Expect.isNull(msg);
}
