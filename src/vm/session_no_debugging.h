// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SESSION_NO_DEBUGGING_H_
#define SRC_VM_SESSION_NO_DEBUGGING_H_

#ifndef SRC_VM_SESSION_H_
#error "Do not import session_no_debugging.h directly, import session.h"
#endif  // SRC_VM_SESSION_H_

namespace dartino {

class Connection;
class Process;
class PointerVisitor;

class Session {
 public:
  explicit Session(Connection* connection) { UNIMPLEMENTED(); }

  int FreshProcessId() {
    UNIMPLEMENTED();
    return -1;
  }

  void Initialize(Program* program) { UNIMPLEMENTED(); }

  void StartMessageProcessingThread() { UNIMPLEMENTED(); }

  void JoinMessageProcessingThread() { UNIMPLEMENTED(); }

  bool CanHandleEvents() const {
    UNIMPLEMENTED();
    return false;
  }

  Scheduler::ProcessInterruptionEvent UncaughtException(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  Scheduler::ProcessInterruptionEvent UnhandledSignal(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  Scheduler::ProcessInterruptionEvent Breakpoint(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  Scheduler::ProcessInterruptionEvent ProcessTerminated(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  Scheduler::ProcessInterruptionEvent CompileTimeError(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  bool is_debugging() const {
    UNIMPLEMENTED();
    return false;
  }

  int ProcessRun() {
    UNIMPLEMENTED();
    return 0;
  }

  Scheduler::ProcessInterruptionEvent Killed(Process* process) {
    UNIMPLEMENTED();
    return Scheduler::kUnhandled;
  }

  void IteratePointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
};

}  // namespace dartino

#endif  // SRC_VM_SESSION_NO_DEBUGGING_H_
