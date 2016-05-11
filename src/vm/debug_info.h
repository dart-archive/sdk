// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DEBUG_INFO_H_
#define SRC_VM_DEBUG_INFO_H_

#ifndef DARTINO_ENABLE_DEBUGGING
#include "src/vm/debug_info_no_debugging.h"
#else  // DARTINO_ENABLE_DEBUGGING

#include "src/vm/hash_map.h"
#include "src/vm/object.h"

namespace dartino {

class Breakpoint {
 public:
  static const int kNoBreakpointId = -1;
  static Breakpoint kBreakOnAllBytecodes;

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
  const Map& map() const { return breakpoints_; }
  ConstIterator Begin() const { return breakpoints_.Begin(); }
  ConstIterator End() const { return breakpoints_.End(); }
  ConstIterator Find(uint8_t* bcp) { return breakpoints_.Find(bcp); }
  void Insert(Entry entry) { breakpoints_.Insert(entry); }
  bool IsEmpty() const { return Begin() == End(); }

  bool Delete(int id);
  const Breakpoint* Lookup(uint8_t* bcp) const;

  // GC support.
  void VisitPointers(PointerVisitor* visitor);
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  Map breakpoints_;
};

class ProgramDebugInfo {
 public:
  ProgramDebugInfo() : next_process_id_(0), next_breakpoint_id_(0) {}

  int CreateBreakpoint(Function* function, int bytecode_index);

  bool DeleteBreakpoint(int id);

  const Breakpoint* GetBreakpointAt(uint8_t* bcp) const;

  int NextProcessId() { return next_process_id_++; }

  int NextBreakpointId() { return next_breakpoint_id_++; }

  const Breakpoints* breakpoints() const { return &breakpoints_; }

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();
  // VisitPointers is not needed because program breakpoints cannot have
  // pointers to the object heap, ie, the coroutine pointer is always NULL.

 private:
  int next_process_id_;
  int next_breakpoint_id_;
  Breakpoints breakpoints_;
};

class ProcessDebugInfo {
 public:
  explicit ProcessDebugInfo(ProgramDebugInfo* program_info);

  const Breakpoint* GetBreakpointAt(uint8_t* bcp, Object** sp) const;

  void SetCurrentBreakpoint(const Breakpoint* breakpoint);

  int CreateBreakpoint(
      Function* function,
      int bytecode_index,
      Coroutine* coroutine = NULL,
      word stack_height = 0);

  bool DeleteBreakpoint(int id);

  // Returns kNoBreakpointId associated with having set stepping.
  int SetStepping();

  void ClearSteppingFromBreakPoint();

  void ClearSteppingInterrupted();

  void ClearCurrentBreakpoint() {
    ASSERT(is_at_breakpoint_);
    is_at_breakpoint_ = false;
    current_breakpoint_id_ = Breakpoint::kNoBreakpointId;
  }

  int process_id() const { return process_id_; }

  bool is_stepping() const { return is_stepping_; }

  bool is_at_breakpoint() const { return is_at_breakpoint_; }

  int current_breakpoint_id() const { return current_breakpoint_id_; }

  const Breakpoints* breakpoints() const { return &breakpoints_; }

  // GC support for process GCs.
  void VisitPointers(PointerVisitor* visitor);

  // GC support for program GCs.
  void VisitProgramPointers(PointerVisitor* visitor);
  void UpdateBreakpoints();

 private:
  void SetCurrentBreakpoint(int id) {
    ASSERT(!is_at_breakpoint_);
    is_at_breakpoint_ = true;
    current_breakpoint_id_ = id;
  }

  int NextBreakpointId();

  ProgramDebugInfo* program_info_;
  int process_id_;
  Breakpoints breakpoints_;

  bool is_stepping_;
  bool is_at_breakpoint_;
  int current_breakpoint_id_;
};

}  // namespace dartino

#endif  // DARTINO_ENABLE_DEBUGGING

#endif  // SRC_VM_DEBUG_INFO_H_
