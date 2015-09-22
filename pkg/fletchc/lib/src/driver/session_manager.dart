// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.session_manager;

import 'dart:async' show
    Future;

import 'driver_commands.dart' show
    CommandSender;

import 'driver_main.dart' show
    IsolateController;

export 'driver_main.dart' show
    IsolateController;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError,
    throwInternalError;

import '../../fletch_system.dart' show
    FletchDelta;

export '../../fletch_system.dart' show
    FletchDelta;

import '../../session.dart' show
    Session;

export '../../session.dart' show
    Session;

import '../../fletch_compiler.dart' show
    FletchCompiler;

export '../../fletch_compiler.dart' show
    FletchCompiler;

import '../../incremental/fletchc_incremental.dart' show
    IncrementalCompiler;

export '../../incremental/fletchc_incremental.dart' show
    IncrementalCompiler;

import '../../fletch_vm.dart' show
    FletchVm;

export '../../fletch_vm.dart' show
    FletchVm;

final Map<String, UserSession> internalSessions = <String, UserSession>{};

String internalCurrentSession = "default";

String get currentSession => internalCurrentSession;

Future<UserSession> createSession(
    String name,
    Future<IsolateController> allocateWorker()) async {
  UserSession session = lookupSession(name);
  if (session != null) {
    throwFatalError(DiagnosticKind.sessionAlreadyExists, sessionName: name);
  }
  session = new UserSession(name, await allocateWorker());
  internalSessions[name] = session;
  // TODO(ahe): We need a command to switch to another session.
  internalCurrentSession = name;
  return session;
}

UserSession lookupSession(String name) => internalSessions[name];

// Remove the session named [name] from [internalSessions], but caller must
// ensure that [worker] has its static state cleaned up and returned to the
// isolate pool.
UserSession endSession(String name) {
  UserSession session = internalSessions.remove(name);
  if (session == null) {
    throwFatalError(DiagnosticKind.noSuchSession, sessionName: name);
  }
  return session;
}

void endAllSessions() {
  internalSessions.forEach((String name, UserSession session) {
    print("Ending session: $name");
    session.worker.endSession();
  });
  internalSessions.clear();
}

/// A session in the main isolate.
class UserSession {
  final String name;

  final IsolateController worker;

  UserSession(this.name, this.worker);
}

typedef void SendBytesFunction(List<int> bytes);

class BufferingOutputSink implements Sink<List<int>> {
  SendBytesFunction sendBytes;

  List<List<int>> buffer = new List();

  void attachCommandSender(SendBytesFunction sendBytes) {
    for (List<int> data in buffer) {
      sendBytes(data);
    }
    buffer = new List();
    this.sendBytes = sendBytes;
  }

  void detachCommandSender() {
    assert(sendBytes != null);
    sendBytes = null;
  }

  void add(List<int> bytes) {
    if (sendBytes != null) {
      sendBytes(bytes);
    } else {
      buffer.add(bytes);
    }
  }

  void close() {
    throwInternalError("Unimplemented");
  }
}

/// The state stored in a worker isolate of a [UserSession].
class SessionState {
  final String name;

  final BufferingOutputSink stdoutSink = new BufferingOutputSink();

  final BufferingOutputSink stderrSink = new BufferingOutputSink();

  final FletchCompiler compilerHelper;

  final IncrementalCompiler compiler;

  final List<FletchDelta> compilationResults = <FletchDelta>[];

  final List<String> loggedMessages = <String>[];

  Uri script;

  Session session;

  FletchVm fletchVm;

  SessionState(this.name, this.compilerHelper, this.compiler);

  void addCompilationResult(FletchDelta delta) {
    compilationResults.add(delta);
  }

  void resetCompiler() {
    compilationResults.clear();
  }

  void attachCommandSender(CommandSender sender) {
    stdoutSink.attachCommandSender((d) => sender.sendStdoutBytes(d));
    stderrSink.attachCommandSender((d) => sender.sendStderrBytes(d));
  }

  void detachCommandSender() {
    stdoutSink.detachCommandSender();
    stderrSink.detachCommandSender();
  }

  void log(message) {
    loggedMessages.add("[$name: ${new DateTime.now()} $message]");
  }

  String flushLog() {
    String result = loggedMessages.join("\n");
    loggedMessages.clear();
    return result;
  }

  static SessionState internalCurrent;

  static SessionState get current => internalCurrent;
}
