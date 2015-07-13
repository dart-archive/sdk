// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver.session_manager;

import 'driver_main.dart' show
    IsolateController;

final Map<String, UserSession> internalSessions = <String, UserSession>{};

UserSession createSession(String name, IsolateController worker) {
  UserSession session = lookupSession(name);
  if (session != null) {
    throw new StateError(
        "Can't create session named '$name'; "
        "There already is a session named '$name'.");
  }
  session = new UserSession(name, worker);
  internalSessions[name] = session;
  return session;
}

UserSession lookupSession(String name) => internalSessions[name];

class UserSession {
  final String name;

  final IsolateController worker;

  UserSession(this.name, this.worker);
}
