// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/vm/debug_info.h"

#include "src/shared/bytecodes.h"
#include "src/vm/object.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/process.h"

namespace fletch {

static Mutex* breakpoint_mutex = new Mutex();

Breakpoint::Breakpoint(Function* function,
                       int bytecode_index,
                       int id,
                       bool is_one_shot,
                       Coroutine* coroutine,
                       word stack_height)
    : function_(function),
      bytecode_index_(bytecode_index),
      id_(id),
      is_one_shot_(is_one_shot),
      coroutine_(coroutine),
      stack_height_(stack_height) { }

void Breakpoint::VisitPointers(PointerVisitor* visitor) {
  if (coroutine_ != NULL) {
    visitor->Visit(reinterpret_cast<Object**>(&coroutine_));
  }
}

void Breakpoint::VisitProgramPointers(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&function_));
}

DebugInfo::DebugInfo()
    : is_stepping_(false),
      is_at_breakpoint_(false),
      current_breakpoint_id_(kNoBreakpointId),
      next_breakpoint_id_(0) { }

bool DebugInfo::ShouldBreak(uint8_t* bcp, Object** sp) {
  BreakpointMap::ConstIterator it = breakpoints_.Find(bcp);
  if (it != breakpoints_.End()) {
    const Breakpoint& breakpoint = it->second;
    Stack* breakpoint_stack = breakpoint.stack();
    if (breakpoint_stack != NULL) {
      // Step-over breakpoint that only matches if the stack height
      // is correct.
      word index = breakpoint_stack->length() - breakpoint.stack_height();
      Object** expected_sp = breakpoint_stack->Pointer(index);
      ASSERT(sp <= expected_sp);
      if (expected_sp != sp) return false;
    }
    SetCurrentBreakpoint(breakpoint.id());
    if (breakpoint.is_one_shot()) DeleteBreakpoint(breakpoint.id());
    return true;
  }
  if (is_stepping_) {
    SetCurrentBreakpoint(kNoBreakpointId);
    return true;
  }
  return false;
}

int DebugInfo::SetBreakpoint(Function* function,
                             int bytecode_index,
                             bool one_shot,
                             Coroutine* coroutine,
                             word stack_height) {
  Breakpoint breakpoint(function,
                        bytecode_index,
                        NextBreakpointId(),
                        one_shot,
                        coroutine,
                        stack_height);
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  BreakpointMap::ConstIterator it = breakpoints_.Find(bcp);
  if (it != breakpoints_.End()) return it->second.id();
  {
    ScopedLock lock(breakpoint_mutex);
    Opcode opcode = static_cast<Opcode>(*bcp);
    BreakAtBytecode(opcode);
  }
  breakpoints_.Insert({bcp, breakpoint});
  return breakpoint.id();
}

bool DebugInfo::DeleteBreakpoint(int id) {
  BreakpointMap::ConstIterator it = breakpoints_.Begin();
  BreakpointMap::ConstIterator end = breakpoints_.End();
  for (; it != end; ++it) {
    if (it->second.id() == id) break;
  }
  if (it != end) {
    uint8* bcp = it->first;
    breakpoints_.Erase(it);

    // If we have other breakpoint with that opcode, return.
    BreakpointMap::ConstIterator it = breakpoints_.Begin();
    BreakpointMap::ConstIterator end = breakpoints_.End();
    for (; it != end; ++it) {
      if (*it->first == *bcp) return true;
    }

    // Not found, clear the opcode.
    ScopedLock lock(breakpoint_mutex);
    ClearBytecodeBreak(static_cast<Opcode>(*bcp));
    return true;
  }
  return false;
}

void DebugInfo::SetStepping() {
  if (is_stepping_) return;
  is_stepping_ = true;
  ScopedLock lock(breakpoint_mutex);
  for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
    BreakAtBytecode(static_cast<Opcode>(i));
  }
}

void DebugInfo::ClearStepping() {
  is_stepping_ = false;
}

void DebugInfo::ClearBreakpoint() {
  is_at_breakpoint_ = false;
  current_breakpoint_id_ = kNoBreakpointId;
  if (is_stepping_) return;

  ScopedLock lock(breakpoint_mutex);

  for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
    ClearBytecodeBreak(static_cast<Opcode>(i));
  }

  BreakpointMap::ConstIterator it = breakpoints_.Begin();
  BreakpointMap::ConstIterator end = breakpoints_.End();
  for (; it != end; ++it) {
    BreakAtBytecode(static_cast<Opcode>(*it->first));
  }
}

void DebugInfo::VisitPointers(PointerVisitor* visitor) {
  BreakpointMap::Iterator it = breakpoints_.Begin();
  BreakpointMap::Iterator end = breakpoints_.End();
  for (; it != end; ++it) {
    it->second.VisitPointers(visitor);
  }
}

void DebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  BreakpointMap::Iterator it = breakpoints_.Begin();
  BreakpointMap::Iterator end = breakpoints_.End();
  for (; it != end; ++it) {
    it->second.VisitProgramPointers(visitor);
  }
}

void DebugInfo::UpdateBreakpoints() {
  BreakpointMap new_breakpoints;

  ScopedLock lock(breakpoint_mutex);

  if (!is_stepping_) {
    for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
      ClearBytecodeBreak(static_cast<Opcode>(i));
    }
  }

  BreakpointMap::ConstIterator it = breakpoints_.Begin();
  BreakpointMap::ConstIterator end = breakpoints_.End();
  for (; it != end; ++it) {
    Function* function = it->second.function();
    uint8_t* bcp =
        function->bytecode_address_for(0) + it->second.bytecode_index();
    BreakAtBytecode(static_cast<Opcode>(*bcp));
    new_breakpoints.Insert({bcp, it->second});
  }
  breakpoints_.Swap(new_breakpoints);
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
