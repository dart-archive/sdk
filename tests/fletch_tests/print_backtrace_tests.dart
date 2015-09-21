// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library test.print_backtrace_test;

import 'dart:io';

import 'package:expect/expect.dart';

import 'package:fletchc/src/driver/developer.dart' show
    printBacktraceHack,
    run;

import 'package:fletchc/src/verbs/infrastructure.dart';

import 'package:fletchc/fletch_system.dart' show
    FletchSystem;

import 'package:fletchc/commands.dart' as commands_lib;

import 'package:fletchc/src/diagnostic.dart';

import 'package:fletchc/session.dart' as session_lib;

abstract class MockSession implements session_lib.Session {
  final Iterator replies;

  MockSession(this.replies);

  _getNextReply() async {
    if (!replies.moveNext()) {
      throw "no more replies";
    }
    return replies.current;
  }

  Future applyDelta(_) => null;

  Future runCommand(_) => _getNextReply();

  Future runCommands(_) => _getNextReply();

  Future sendCommand(_) => _getNextReply();

  Future readNextCommand({bool force: true}) => _getNextReply();

  Future kill() async => new Future.value(null);

  Future shutdown({bool ignoreExtraCommands: false}) => new Future.value(null);
}

@proxy
class MockSessionProxy extends MockSession  {
  MockSessionProxy(Iterator replies)
      : super(replies);

  noSuchMethod(invocation) => super.noSuchMethod(invocation);
}

abstract class MockFletchSystem implements FletchSystem {
  lookupFunctionById(_) => null;
}

@proxy
class MockFletchSystemProxy extends MockFletchSystem  {
  noSuchMethod(invocation) => super.noSuchMethod(invocation);
}

abstract class MockFletchDelta implements FletchDelta {
  get commands => null;
}

@proxy
class MockFletchDeltaProxy extends MockFletchDelta  {
  noSuchMethod(invocation) => super.noSuchMethod(invocation);
}

Iterable nullForever() sync* {
  while (true) {
    yield null;
  }
}

/// Test that [runTask] doesn't crash (unexpectedly) if the VM unexpectedly
/// closes the connection.
simulateVmCrash() async {
  SessionState state = new SessionState(null, null, null);
  state.compilationResults.add(new MockFletchDeltaProxy());
  state.session = new MockSessionProxy(nullForever().iterator);

  try {
    await run(state);
    throw "expected InputError";
  } on InputError catch (e) {
    Expect.equals(DiagnosticKind.internalError, e.kind);
    Expect.stringEquals(
        "No command received from Fletch VM",
        e.arguments[DiagnosticParameter.message]);
  }

  if (false) {
    // Workaround unused hint from dart2js.
    new MockSessionProxy(null).noSuchMethod(null);
    new MockFletchSystemProxy().noSuchMethod(null);
    new MockFletchDeltaProxy().noSuchMethod(null);
  }
}

/// Test that [printBacktraceHack] doesn't crash (unexpectedly) on a null
/// backtrace.
simulateNullBacktrace() async {
  try {
    await printBacktraceHack(
        new MockSessionProxy(nullForever().iterator),
        new MockFletchSystemProxy());
    throw "expected InputError";
  } on InputError catch (e) {
    Expect.equals(DiagnosticKind.internalError, e.kind);
    Expect.stringEquals(
        "No command received from Fletch VM",
        e.arguments[DiagnosticParameter.message]);
  }
}

/// Test that [printBacktraceHack] doesn't crash (unexpectedly) on a backtrace
/// with an unknown function id.
simulateBadBacktraceHack() async {
  commands_lib.ProcessBacktrace backtrace =
      new commands_lib.ProcessBacktrace(1);
  backtrace.functionIds[0] = -1;
  backtrace.bytecodeIndices[0] = -1;

  try {
    await printBacktraceHack(
        new MockSessionProxy([backtrace].iterator),
        new MockFletchSystemProxy());
    throw "expected InputError";
  } on InputError catch (e) {
    Expect.equals(DiagnosticKind.internalError, e.kind);
    Expect.stringEquals(
        "COMPILER BUG in above stacktrace",
        e.arguments[DiagnosticParameter.message]);
  }
}

/// Test that `Session.stackTraceFromBacktraceResponse` deals with missing
/// functions in a backtrace.
simulateBadBacktrace() async {
  commands_lib.ProcessBacktrace backtrace =
      new commands_lib.ProcessBacktrace(1);
  backtrace.functionIds[0] = -1;
  backtrace.bytecodeIndices[0] = -1;

  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  Future<Socket> futureSocket = server.first;

  Socket socketInCompiler =
      await Socket.connect(InternetAddress.LOOPBACK_IP_V4, server.port);
  Socket socketInVm = await futureSocket;
  await server.close();
  var closeSocketInVmFuture = socketInVm.close();

  FletchCompiler compilerHelper = new FletchCompiler();

  session_lib.Session session = new session_lib.Session(
      socketInCompiler, compilerHelper.newIncrementalCompiler(), null, null);

  session.fletchSystem = new MockFletchSystemProxy();

  await session.stackTraceFromBacktraceResponse(backtrace);
  await session.shutdown();
  await closeSocketInVmFuture;
  await socketInVm.listen(null).asFuture();
}
