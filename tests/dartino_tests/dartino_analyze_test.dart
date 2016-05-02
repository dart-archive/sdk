// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import 'package:dartino_compiler/src/hub/client_commands.dart';
import 'package:dartino_compiler/src/hub/hub_main.dart';
import 'package:dartino_compiler/src/hub/session_manager.dart';
import 'package:dartino_compiler/src/verbs/create_verb.dart';
import 'package:dartino_compiler/src/worker/developer.dart';
import 'package:expect/expect.dart';

import 'message_tests.dart';

/// This program exercises the `dartino analyze` functionality
main() async {
  MockClientConnection client;

  // Analyze clean file
  client = await testAnalysis(
      ['analyze', 'samples/stm32f746g-discovery/lines.dart']);
  Expect.equals(0, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectMessage(client.stdoutMessages, "No issues found");

  // Analyze file with syntax error
  client = await testAnalysis(
      ['analyze', 'tests/dartino_tests/file_with_compile_time_error.dart']);
  Expect.equals(3, client.recordedExitCode);
  Expect.isNull(client.recordedError);
  Expect.listEquals([], client.stderrMessages);
  expectMessage(client.stdoutMessages, "Undefined class 'new'");

  print('... "dartino analyze" test passed');
}

Future<MockClientConnection> testAnalysis(List<String> arguments) async {
  print("Command line: ${arguments.join(' ')}");
  MockClientConnection client = new MockClientConnection();
  client.stdoutMessages = <String>[];
  client.parseArguments(arguments);

  String testName = 'analysis-test';
  UserSession session =
      await createSession(testName, () => allocateWorker(pool));
  ClientVerbContext context = new ClientVerbContext(client, pool, session,
      initializer: new CreateSessionTask(testName, null, client.sentence.base));

  var exitCode = await client.sentence.performVerb(context);
  client.recordedExitCode = exitCode;
  endAllSessions();
  pool.shutdown();
  return client;
}

void expectMessage(List<String> messages, String expected) {
  for (String msg in messages) {
    if (msg.contains(expected)) return;
  }
  Expect.fail('Failed to find "$expected" in $messages');
}

