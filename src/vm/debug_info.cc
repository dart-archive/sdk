// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/debug_info.h"

#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

Breakpoint::Breakpoint(Function* function, int bytecode_index, bool is_one_shot)
    : function_(function),
      bytecode_index_(bytecode_index),
      is_one_shot_(is_one_shot) { }

void Breakpoint::VisitProgramPointers(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&function_));
}

DebugInfo::DebugInfo()
    : is_stepping_(false),
      is_at_breakpoint_(false),
      next_breakpoint_index_(0) { }

bool DebugInfo::ShouldBreak(Function* function, int bytecode_index) {
  if (is_stepping_) return true;
  for (int i = 0; i < next_breakpoint_index_; i++) {
    Breakpoint* breakpoint = breakpoints_[i];
    if (breakpoint != NULL &&
        breakpoint->function() == function &&
        breakpoint->bytecode_index() == bytecode_index) {
      if (breakpoint->is_one_shot()) {
        RemoveBreakpoint(i);
      }
      return true;
    }
  }
  return false;
}

int DebugInfo::SetBreakpoint(Function* function, int bytecode_index) {
  if (breakpoints_.length() <= next_breakpoint_index_) {
    breakpoints_.Reallocate(next_breakpoint_index_ + 4);
  }
  Breakpoint* breakpoint = new Breakpoint(function, bytecode_index, false);
  breakpoints_[next_breakpoint_index_] = breakpoint;
  return next_breakpoint_index_++;
}

bool DebugInfo::RemoveBreakpoint(int id) {
  if (id < breakpoints_.length()) {
    delete breakpoints_[id];
    breakpoints_[id] = NULL;
    return true;
  }
  return false;
}

void DebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  for (int i = 0; i < next_breakpoint_index_; i++) {
    Breakpoint* breakpoint = breakpoints_[i];
    if (breakpoint != NULL) breakpoint->VisitProgramPointers(visitor);
  }
}

}  // namespace fletch
