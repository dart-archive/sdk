// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_NO_DEBUGGING_H_
#define SRC_VM_DEBUG_INFO_NO_DEBUGGING_H_

#ifndef SRC_VM_DEBUG_INFO_H_
#error "Do not import debug_info_no_debugging.h directly, import debug_info.h"
#endif  // SRC_VM_DEBUG_INFO_H_

#include "src/shared/assert.h"

namespace dartino {

class Breakpoint;
class Coroutine;
class Function;
class Object;
class PointerVisitor;

class ProgramDebugInfo {
 public:
  const Breakpoint* GetBreakpointAt(uint8* bcp) const {
    UNIMPLEMENTED();
    return NULL;
  }

  void VisitProgramPointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
  void UpdateBreakpoints() { UNIMPLEMENTED(); }
};

class ProcessDebugInfo {
 public:
  explicit ProcessDebugInfo(ProgramDebugInfo* program_info) {
    UNIMPLEMENTED();
  }

  const Breakpoint* GetBreakpointAt(uint8* bcp, Object** sp) const {
    UNIMPLEMENTED();
    return NULL;
  }

  void SetCurrentBreakpoint(const Breakpoint* breakpoint) { UNIMPLEMENTED(); }

  int CreateBreakpoint(
      Function* function,
      int bytecode_index,
      Coroutine* coroutine = NULL,
      word stack_height = 0) {
    UNIMPLEMENTED();
    return -1;
  }

  int SetStepping() {
    UNIMPLEMENTED();
    return -1;
  }

  void ClearCurrentBreakpoint() { UNIMPLEMENTED(); }

  bool is_at_breakpoint() const {
    UNIMPLEMENTED();
    return false;
  }

  void VisitPointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
  void VisitProgramPointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
  void UpdateBreakpoints() { UNIMPLEMENTED(); }
};

}  // namespace dartino

#endif  // SRC_VM_DEBUG_INFO_NO_DEBUGGING_H_
