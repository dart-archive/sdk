// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.session_manager;

import 'dart:async' show
    Future;

import 'driver_main.dart' show
    IsolateController;

import '../diagnostic.dart' show
    DiagnosticKind,
    throwFatalError;

import '../../fletch_system.dart' show
    FletchDelta;

final Map<String, UserSession> internalSessions = <String, UserSession>{};

Future<UserSession> createSession(
    String name,
    Future<IsolateController> allocateWorker()) async {
  UserSession session = lookupSession(name);
  if (session != null) {
    throwFatalError(DiagnosticKind.sessionAlreadyExists, sessionName: name);
  }
  session = new UserSession(name, await allocateWorker());
  internalSessions[name] = session;
  return session;
}

UserSession lookupSession(String name) => internalSessions[name];

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

/// The state stored in a worker isolate of a [UserSession].
class SessionState {
  final String name;

  FletchDelta compilationResult;

  SessionState(this.name);

  static SessionState internalCurrent;

  static SessionState get current => internalCurrent;
}
