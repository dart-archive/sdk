// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef DARTINO_ENABLE_LIVE_CODING

#include "src/vm/debug_info.h"

#include "src/shared/bytecodes.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace dartino {

Breakpoint Breakpoint::kBreakOnAllBytecodes =
    Breakpoint(NULL, -1, kNoBreakpointId, false);

Breakpoint::Breakpoint(Function* function, int bytecode_index, int id,
                       bool is_one_shot, Coroutine* coroutine,
                       word stack_height)
    : function_(function),
      bytecode_index_(bytecode_index),
      id_(id),
      is_one_shot_(is_one_shot),
      coroutine_(coroutine),
      stack_height_(stack_height) {}

void Breakpoint::VisitPointers(PointerVisitor* visitor) {
  if (coroutine_ != NULL) {
    visitor->Visit(reinterpret_cast<Object**>(&coroutine_));
  }
}

void Breakpoint::VisitProgramPointers(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&function_));
}

const Breakpoint* Breakpoints::Lookup(uint8_t* bcp) const {
  Breakpoints::ConstIterator it = breakpoints_.Find(bcp);
  if (it != breakpoints_.End()) {
    return &it->second;
  }
  return NULL;
}

bool Breakpoints::Delete(int id) {
  Breakpoints::ConstIterator it = breakpoints_.Begin();
  Breakpoints::ConstIterator end = breakpoints_.End();
  for (; it != end; ++it) {
    if (it->second.id() == id) {
      breakpoints_.Erase(it);
      return true;
    }
  }
  return false;
}

void Breakpoints::VisitPointers(PointerVisitor* visitor) {
  for (auto& pair : breakpoints_) pair.second.VisitPointers(visitor);
}

void Breakpoints::VisitProgramPointers(PointerVisitor* visitor) {
  for (auto& pair : breakpoints_) pair.second.VisitProgramPointers(visitor);
}

// Update breakpoints with new bytecode pointer values after GC.
void Breakpoints::UpdateBreakpoints() {
  Map new_breakpoints;
  for (auto& pair : breakpoints_) {
    Function* function = pair.second.function();
    uint8_t* bcp =
        function->bytecode_address_for(0) + pair.second.bytecode_index();
    new_breakpoints.Insert({bcp, pair.second});
  }
  breakpoints_.Swap(new_breakpoints);
}

ProcessDebugInfo::ProcessDebugInfo(ProgramDebugInfo* program_info)
    : program_info_(program_info),
      process_id_(program_info->NextProcessId()),
      is_stepping_(false),
      is_at_breakpoint_(false),
      current_breakpoint_id_(Breakpoint::kNoBreakpointId) {}

int ProcessDebugInfo::NextBreakpointId() {
  return program_info_->NextBreakpointId();
}

const Breakpoint* ProgramDebugInfo::GetBreakpointAt(uint8_t* bcp) const {
  return breakpoints_.Lookup(bcp);
}

const Breakpoint* ProcessDebugInfo::GetBreakpointAt(uint8_t* bcp, Object** sp)
    const {
  if (is_stepping_) {
    return &Breakpoint::kBreakOnAllBytecodes;
  }
  const Breakpoint* breakpoint = breakpoints_.Lookup(bcp);
  if (breakpoint != NULL) {
    Stack* breakpoint_stack = breakpoint->stack();
    if (breakpoint_stack != NULL) {
      // Step-over breakpoint that only matches if the stack height
      // is correct.
      word index = breakpoint_stack->length() - breakpoint->stack_height();
      Object** expected_sp = breakpoint_stack->Pointer(index);
      ASSERT(sp <= expected_sp);
      if (expected_sp != sp) return NULL;
    }
    return breakpoint;
  }
  return NULL;
}

void ProcessDebugInfo::SetCurrentBreakpoint(const Breakpoint* breakpoint) {
  ASSERT(breakpoint != NULL);
  SetCurrentBreakpoint(breakpoint->id());
  if (breakpoint->is_one_shot()) DeleteBreakpoint(breakpoint->id());
}

int ProgramDebugInfo::CreateBreakpoint(Function* function, int bytecode_index) {
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  const Breakpoint* existing = breakpoints_.Lookup(bcp);
  if (existing != NULL) {
    return existing->id();
  }
  Breakpoint breakpoint(
      function, bytecode_index, NextBreakpointId(), false, NULL, 0);
  breakpoints_.Insert({bcp, breakpoint});
  return breakpoint.id();
}

int ProcessDebugInfo::CreateBreakpoint(
    Function* function,
    int bytecode_index,
    Coroutine* coroutine,
    word stack_height) {
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  // Assert that a process-local breakpoint does not already exist.
  ASSERT(breakpoints_.Lookup(bcp) == NULL);
  Breakpoint breakpoint(function, bytecode_index, NextBreakpointId(),
                        /* one_shot */ true, coroutine, stack_height);
  breakpoints_.Insert({bcp, breakpoint});
  return breakpoint.id();
}

bool ProgramDebugInfo::DeleteBreakpoint(int id) {
  return breakpoints_.Delete(id);
}

bool ProcessDebugInfo::DeleteBreakpoint(int id) {
  return breakpoints_.Delete(id);
}

// SetStepping ensures that all bytecodes will trigger and updates the state to
// be on a breakpoint. This ensures that resuming will not break on the first
// executed bytecode since it was already at that breakpoint.
int ProcessDebugInfo::SetStepping() {
  ASSERT(!is_stepping_);
  if (is_at_breakpoint_) ClearCurrentBreakpoint();
  is_stepping_ = true;
  SetCurrentBreakpoint(Breakpoint::kNoBreakpointId);
  return Breakpoint::kNoBreakpointId;
}

// Converse to SetStepping, ClearSteppingFromBreakPoint restores bytecode breaks
// for the actual breakpoints and clears the current breakpoint. This can only
// be called when the state was actually stepping and the current breakpoint is
// a cause of stepping.
void ProcessDebugInfo::ClearSteppingFromBreakPoint() {
  ASSERT(is_stepping_);
  ASSERT(is_at_breakpoint_);
  ASSERT(current_breakpoint_id_ == Breakpoint::kNoBreakpointId);
  is_stepping_ = false;
  ClearCurrentBreakpoint();
}

// Clears the stepping when the program has stopped for another reason than
// hitting a breakpoint.
void ProcessDebugInfo::ClearSteppingInterrupted() {
  ASSERT(is_stepping_);
  is_stepping_ = false;
}

void ProgramDebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  breakpoints_.VisitProgramPointers(visitor);
}

void ProcessDebugInfo::VisitPointers(PointerVisitor* visitor) {
  breakpoints_.VisitPointers(visitor);
}

void ProcessDebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  breakpoints_.VisitProgramPointers(visitor);
}

void ProgramDebugInfo::UpdateBreakpoints() {
  breakpoints_.UpdateBreakpoints();
}

void ProcessDebugInfo::UpdateBreakpoints() {
  breakpoints_.UpdateBreakpoints();
}

}  // namespace dartino

#endif  // DARTINO_ENABLE_LIVE_CODING
