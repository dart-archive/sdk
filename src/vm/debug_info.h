// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_H_
#define SRC_VM_DEBUG_INFO_H_

#ifndef DARTINO_ENABLE_LIVE_CODING
#include "src/vm/debug_info_no_live_coding.h"
#else  // DARTINO_ENABLE_LIVE_CODING

#include "src/vm/hash_map.h"
#include "src/vm/object.h"

namespace dartino {

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

class Breakpoints {
 public:
  typedef Pair<uint8_t*, Breakpoint> Entry;
  typedef HashMap<uint8_t*, Breakpoint> Map;
  typedef Map::ConstIterator ConstIterator;

  // DebugInfo support.
  const Map& map() { return breakpoints_; }
  ConstIterator Begin() const { return breakpoints_.Begin(); }
  ConstIterator End() const { return breakpoints_.End(); }
  ConstIterator Find(uint8_t* bcp) { return breakpoints_.Find(bcp); }
  ConstIterator Erase(ConstIterator it) { return breakpoints_.Erase(it); }
  void Insert(Entry entry) { breakpoints_.Insert(entry); }
  void SetBytecodeBreaks();

  // GC support.
  void VisitPointers(PointerVisitor* visitor);
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  Map breakpoints_;
};

class DebugInfo {
 public:
  static const int kNoBreakpointId = -1;

  explicit DebugInfo(int process_id, Breakpoints* program_breakpoints);

  bool ShouldBreak(uint8_t* bcp, Object** sp);

  int SetProgramBreakpoint(
      Function* function,
      int bytecode_index);

  int SetProcessLocalBreakpoint(
      Function* function,
      int bytecode_index,
      bool one_shot = false,
      Coroutine* coroutine = NULL,
      word stack_height = 0);

  bool DeleteBreakpoint(int id);

  void SetStepping();

  void ClearStepping();

  int process_id() const { return process_id_; }

  bool is_stepping() const { return is_stepping_; }

  bool is_at_breakpoint() const { return is_at_breakpoint_; }

  int current_breakpoint_id() const { return current_breakpoint_id_; }

  void ClearBreakpoint();

  // GC support for process GCs.
  void VisitPointers(PointerVisitor* visitor);

  // GC support for program GCs.
  static void ClearBytecodeBreaks();
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  void ClearCurrentBreakpoint() {
    ASSERT(is_at_breakpoint_);
    is_at_breakpoint_ = false;
    current_breakpoint_id_ = kNoBreakpointId;
  }

  void SetCurrentBreakpoint(int id) {
    ASSERT(!is_at_breakpoint_);
    is_at_breakpoint_ = true;
    current_breakpoint_id_ = id;
  }

  int NextBreakpointId();

  const Breakpoint* LookupBreakpointByBCP(uint8_t* bcp);
  const Breakpoint* LookupBreakpointByOpcode(uint8_t opcode);
  uint8_t* EraseBreakpointById(int id);

  int process_id_;

  bool is_stepping_;
  bool is_at_breakpoint_;
  int current_breakpoint_id_;

  Breakpoints process_breakpoints_;
  Breakpoints* program_breakpoints_;
};

}  // namespace dartino

#endif  // DARTINO_ENABLE_LIVE_CODING

#endif  // SRC_VM_DEBUG_INFO_H_
