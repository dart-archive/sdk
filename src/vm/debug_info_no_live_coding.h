// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_NO_LIVE_CODING_H_
#define SRC_VM_DEBUG_INFO_NO_LIVE_CODING_H_

#ifndef SRC_VM_DEBUG_INFO_H_
#error "Do not import debug_info_no_live_coding.h directly, import debug_info.h"
#endif  // SRC_VM_DEBUG_INFO_H_

#include "src/shared/assert.h"

namespace dartino {

class Coroutine;
class Function;
class Object;
class PointerVisitor;

class Breakpoints {
 public:
  void UpdateBreakpoints() {}
  void VisitPointers(PointerVisitor* visitor) {}
  void VisitProgramPointers(PointerVisitor* visitor) {}
};

class DebugInfo {
 public:
  static const int kNoBreakpointId = -1;

  explicit DebugInfo(int process_id, Breakpoints* program_breakpoints) {
    UNIMPLEMENTED();
  }

  bool ShouldBreak(uint8* bcp, Object** sp) {
    UNIMPLEMENTED();
    return false;
  }

  int SetProgramBreakpoint(Function* function, int bytecode_index) {
    UNIMPLEMENTED();
    return 0;
  }

  int SetProcessLocalBreakpoint(
      Function* function, int bytecode_index,
      bool one_shot = false, Coroutine* coroutine = NULL,
      word stack_height = 0) {
    UNIMPLEMENTED();
    return 0;
  }

  bool is_stepping() const {
    UNIMPLEMENTED();
    return false;
  }

  bool is_at_breakpoint() const {
    UNIMPLEMENTED();
    return false;
  }

  void ClearCurrentBreakpoint() { UNIMPLEMENTED(); }

  void SetStepping() { UNIMPLEMENTED(); }
  void ClearStepping() { UNIMPLEMENTED(); }

  // GC support.
  static void ClearBytecodeBreaks() {}
  void VisitPointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
  void VisitProgramPointers(PointerVisitor* visitor) { UNIMPLEMENTED(); }
  void UpdateBreakpoints() { UNIMPLEMENTED(); }
};

}  // namespace dartino

#endif  // SRC_VM_DEBUG_INFO_NO_LIVE_CODING_H_
