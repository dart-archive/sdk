// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_H_
#define SRC_VM_DEBUG_INFO_H_

#ifndef FLETCH_ENABLE_LIVE_CODING
#include "src/vm/debug_info_no_live_coding.h"
#else  // FLETCH_ENABLE_LIVE_CODING

#include "src/vm/hash_map.h"
#include "src/vm/object.h"

namespace fletch {

class Breakpoint {
 public:
  Breakpoint(Function* function, int bytecode_index, int id, bool is_one_shot,
             Coroutine* coroutine = NULL, word stack_height = 0);

  Function* function() const { return function_; }
  int bytecode_index() const { return bytecode_index_; }
  int id() const { return id_; }
  bool is_one_shot() const { return is_one_shot_; }
  Stack* stack() const {
    if (coroutine_ == NULL) return NULL;
    return coroutine_->stack();
  }
  word stack_height() const { return stack_height_; }

  // GC support for process GCs.
  void VisitPointers(PointerVisitor* visitor);

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);

 private:
  Function* function_;
  int bytecode_index_;
  int id_;
  bool is_one_shot_;
  Coroutine* coroutine_;
  word stack_height_;
};

class DebugInfo {
 public:
  static const int kNoBreakpointId = -1;

  explicit DebugInfo(int process_id);

  bool ShouldBreak(uint8_t* bcp, Object** sp);
  int SetBreakpoint(Function* function, int bytecode_index,
                    bool one_shot = false, Coroutine* coroutine = NULL,
                    word stack_height = 0);

  bool DeleteBreakpoint(int id);

  void SetStepping();

  void ClearStepping();

  void clear_current_breakpoint() {
    is_at_breakpoint_ = false;
    current_breakpoint_id_ = kNoBreakpointId;
  }

  int process_id() const { return process_id_; }

  bool is_stepping() const { return is_stepping_; }

  bool is_at_breakpoint() const { return is_at_breakpoint_; }

  int current_breakpoint_id() const { return current_breakpoint_id_; }

  void ClearBreakpoint();

  // GC support for process GCs.
  void VisitPointers(PointerVisitor* visitor);

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  void SetCurrentBreakpoint(int id) {
    is_at_breakpoint_ = true;
    current_breakpoint_id_ = id;
  }

  int NextBreakpointId() { return next_breakpoint_id_++; }

  int process_id_;

  bool is_stepping_;
  bool is_at_breakpoint_;
  int current_breakpoint_id_;

  typedef HashMap<uint8_t*, Breakpoint> BreakpointMap;
  BreakpointMap breakpoints_;
  int next_breakpoint_id_;
};

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING

#endif  // SRC_VM_DEBUG_INFO_H_
