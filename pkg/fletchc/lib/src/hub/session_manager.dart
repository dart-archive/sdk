// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.hub.session_manager;

import 'dart:async' show
    Future,
    Timer;

import 'client_commands.dart' show
    CommandSender;

import 'hub_main.dart' show
    WorkerConnection;

export 'hub_main.dart' show
    WorkerConnection;

import '../worker/developer.dart' show
    Settings;

import '../diagnostic.dart' show
    DiagnosticKind,
    DiagnosticParameter,
    InputError,
    throwFatalError,
    throwInternalError;

import '../../fletch_system.dart' show
    FletchDelta;

export '../../fletch_system.dart' show
    FletchDelta;

import '../../vm_session.dart' show
    Session;

export '../../vm_session.dart' show
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

// TODO(karlklose): we need a better API for session management.
class Sessions {
  static Iterable<String> get names {
    return internalSessions.keys;
  }
}

final Map<String, UserSession> internalSessions = <String, UserSession>{};

// TODO(ahe): We need a command to switch to another session.
String internalCurrentSession = "local";

String get currentSession => internalCurrentSession;

Future<UserSession> createSession(
    String name,
    Future<WorkerConnection> allocateWorker()) async {
  if (name == null) {
    throw new ArgumentError("session name must not be `null`.");
  }

  UserSession session = lookupSession(name);
  if (session != null) {
    throwFatalError(DiagnosticKind.sessionAlreadyExists, sessionName: name);
  }
  session = new UserSession(name, await allocateWorker());
  internalSessions[name] = session;
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

/// A session in the hub (main isolate).
class UserSession {
  final String name;

  final WorkerConnection worker;

  bool hasActiveWorkerTask = false;

  UserSession(this.name, this.worker);

  void kill(void printLineOnStderr(String line)) {
    worker.isolate.kill();
    internalSessions.remove(name);
    InputError error = new InputError(
        DiagnosticKind.terminatedSession,
        <DiagnosticParameter, dynamic>{DiagnosticParameter.sessionName: name});
    printLineOnStderr(error.asDiagnostic().formatMessage());
  }
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
/// TODO(wibling): This should be moved into a worker specific file.
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

  int fletchAgentVmId;

  Settings settings;

  SessionState(this.name, this.compilerHelper, this.compiler, this.settings);

  bool get hasRemoteVm => fletchAgentVmId != null;

  bool get colorsDisabled  => session == null ? false : session.colorsDisabled;

  void addCompilationResult(FletchDelta delta) {
    compilationResults.add(delta);
  }

  void resetCompiler() {
    compilationResults.clear();
  }

  Future terminateSession() async {
    if (session != null) {
      if (!session.terminated) {
        bool done = false;
        Timer timer = new Timer(const Duration(seconds: 5), () {
            if (!done) {
              print("Timed out waiting for Fletch VM to shutdown; killing "
                  "session");
              session.kill();
            }
          });
        await session.terminateSession();
        done = true;
        timer.cancel();
      }
    }
    session = null;
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

  String getLog() => loggedMessages.join("\n");

  static SessionState internalCurrent;

  static SessionState get current => internalCurrent;
}
