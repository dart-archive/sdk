// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/debug_info.h"

#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

Breakpoint::Breakpoint(
    Function* function, int bytecode_index, int id, bool is_one_shot)
    : function_(function),
      bytecode_index_(bytecode_index),
      id_(id),
      is_one_shot_(is_one_shot) { }

void Breakpoint::VisitProgramPointers(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&function_));
}

DebugInfo::DebugInfo()
    : is_stepping_(false),
      is_at_breakpoint_(false),
      next_breakpoint_id_(0) { }

bool DebugInfo::ShouldBreak(uint8_t* bcp) {
  if (is_stepping_) return true;
  return breakpoints_.find(bcp) != breakpoints_.end();
}

int DebugInfo::SetBreakpoint(Function* function, int bytecode_index) {
  Breakpoint breakpoint(function, bytecode_index, next_breakpoint_id_++, false);
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  breakpoints_.insert({bcp, breakpoint});
  return breakpoint.id();
}

bool DebugInfo::RemoveBreakpoint(int id) {
  BreakpointMap::const_iterator it = breakpoints_.begin();
  BreakpointMap::const_iterator end = breakpoints_.end();
  for (; it != end; ++it) {
    if (it->second.id() == id) break;
  }
  if (it != end) {
    breakpoints_.erase(it);
    return true;
  }
  return false;
}

void DebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  BreakpointMap::iterator it = breakpoints_.begin();
  BreakpointMap::iterator end = breakpoints_.end();
  for (; it != end; ++it) {
    it->second.VisitProgramPointers(visitor);
  }
}

void DebugInfo::UpdateBreakpoints() {
  BreakpointMap new_breakpoints;
  BreakpointMap::const_iterator it = breakpoints_.begin();
  BreakpointMap::const_iterator end = breakpoints_.end();
  for (; it != end; ++it) {
    Function* function = it->second.function();
    uint8_t* bcp =
        function->bytecode_address_for(0) + it->second.bytecode_index();
    new_breakpoints.insert({bcp, it->second});
  }
  breakpoints_.swap(new_breakpoints);
}

}  // namespace fletch
