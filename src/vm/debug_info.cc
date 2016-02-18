// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef DARTINO_ENABLE_LIVE_CODING

#include "src/vm/debug_info.h"

#include "src/shared/bytecodes.h"
#include "src/vm/object.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/process.h"

namespace dartino {

static Mutex* breakpoint_mutex = new Mutex();
static int next_breakpoint_id = 0;

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


void Breakpoints::SetBytecodeBreaks() {
  ScopedLock lock(breakpoint_mutex);
  for (auto& pair : breakpoints_) {
    SetBytecodeBreak(static_cast<Opcode>(*pair.first));
  }
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
  ScopedLock lock(breakpoint_mutex);
  for (auto& pair : breakpoints_) {
    Function* function = pair.second.function();
    uint8_t* bcp =
        function->bytecode_address_for(0) + pair.second.bytecode_index();
    SetBytecodeBreak(static_cast<Opcode>(*bcp));
    new_breakpoints.Insert({bcp, pair.second});
  }
  breakpoints_.Swap(new_breakpoints);
}

DebugInfo::DebugInfo(int process_id, Breakpoints* program_breakpoints)
    : process_id_(process_id),
      is_stepping_(false),
      is_at_breakpoint_(false),
      current_breakpoint_id_(kNoBreakpointId),
      program_breakpoints_(program_breakpoints) {}

int DebugInfo::NextBreakpointId() {
  return next_breakpoint_id++;
}

const Breakpoint* DebugInfo::LookupBreakpointByBCP(uint8_t* bcp) {
  Breakpoints::ConstIterator it = program_breakpoints_->Find(bcp);
  if (it != program_breakpoints_->End()) {
    return &it->second;
  }
  it = process_breakpoints_.Find(bcp);
  if (it != process_breakpoints_.End()) {
    return &it->second;
  }
  return NULL;
}

const Breakpoint* DebugInfo::LookupBreakpointByOpcode(uint8_t opcode) {
  for (auto& pair : program_breakpoints_->map()) {
    if (*pair.first == opcode) return &pair.second;
  }
  for (auto& pair : process_breakpoints_.map()) {
    if (*pair.first == opcode) return &pair.second;
  }
  return NULL;
}

uint8_t* DebugInfo::EraseBreakpointById(int id) {
  Breakpoints::ConstIterator it = program_breakpoints_->Begin();
  Breakpoints::ConstIterator end = program_breakpoints_->End();
  for (; it != end; ++it) {
    if (it->second.id() == id) {
      uint8* bcp = it->first;
      program_breakpoints_->Erase(it);
      return bcp;
    }
  }
  it = process_breakpoints_.Begin();
  end = process_breakpoints_.End();
  for (; it != end; ++it) {
    if (it->second.id() == id) {
      uint8* bcp = it->first;
      process_breakpoints_.Erase(it);
      return bcp;
    }
  }
  return 0;
}

bool DebugInfo::ShouldBreak(uint8_t* bcp, Object** sp) {
  const Breakpoint* breakpoint = LookupBreakpointByBCP(bcp);
  if (breakpoint != NULL) {
    Stack* breakpoint_stack = breakpoint->stack();
    if (breakpoint_stack != NULL) {
      // Step-over breakpoint that only matches if the stack height
      // is correct.
      word index = breakpoint_stack->length() - breakpoint->stack_height();
      Object** expected_sp = breakpoint_stack->Pointer(index);
      ASSERT(sp <= expected_sp);
      if (expected_sp != sp) return false;
    }
    SetCurrentBreakpoint(breakpoint->id());
    if (breakpoint->is_one_shot()) DeleteBreakpoint(breakpoint->id());
    return true;
  }
  if (is_stepping_) {
    SetCurrentBreakpoint(kNoBreakpointId);
    return true;
  }
  return false;
}

int DebugInfo::SetProgramBreakpoint(Function* function, int bytecode_index) {
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  // Only check for existing breakpoint in the program-global set.
  Breakpoints::ConstIterator it = program_breakpoints_->Find(bcp);
  if (it != program_breakpoints_->End()) {
    return it->second.id();
  }
  {
    ScopedLock lock(breakpoint_mutex);
    Opcode opcode = static_cast<Opcode>(*bcp);
    SetBytecodeBreak(opcode);
  }
  Breakpoint breakpoint(
      function, bytecode_index, NextBreakpointId(), false, NULL, 0);
  program_breakpoints_->Insert({bcp, breakpoint});
  return breakpoint.id();
}

int DebugInfo::SetProcessLocalBreakpoint(Function* function, int bytecode_index,
                                         bool one_shot, Coroutine* coroutine,
                                         word stack_height) {
  ASSERT(one_shot);
  uint8_t* bcp = function->bytecode_address_for(0) + bytecode_index;
  const Breakpoint* existing_breakpoint = LookupBreakpointByBCP(bcp);
  if (existing_breakpoint != NULL) return existing_breakpoint->id();
  {
    ScopedLock lock(breakpoint_mutex);
    Opcode opcode = static_cast<Opcode>(*bcp);
    SetBytecodeBreak(opcode);
  }
  Breakpoint breakpoint(function, bytecode_index, NextBreakpointId(),
                        one_shot, coroutine, stack_height);
  process_breakpoints_.Insert({bcp, breakpoint});
  return breakpoint.id();
}

bool DebugInfo::DeleteBreakpoint(int id) {
  uint8_t* bcp = EraseBreakpointById(id);
  if (bcp != NULL) {
    // If we have another breakpoint with that opcode, return.
    if (LookupBreakpointByOpcode(*bcp) != NULL) {
      return true;
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
    SetBytecodeBreak(static_cast<Opcode>(i));
  }
}

void DebugInfo::ClearStepping() {
  is_stepping_ = false;
}

void DebugInfo::ClearBreakpoint() {
  ClearCurrentBreakpoint();
  if (is_stepping_) return;
  ClearBytecodeBreaks();
  program_breakpoints_->SetBytecodeBreaks();
  process_breakpoints_.SetBytecodeBreaks();
}

void DebugInfo::VisitPointers(PointerVisitor* visitor) {
  process_breakpoints_.VisitPointers(visitor);
}

void DebugInfo::VisitProgramPointers(PointerVisitor* visitor) {
  process_breakpoints_.VisitProgramPointers(visitor);
}

void DebugInfo::UpdateBreakpoints() {
  if (is_stepping_) {
    is_stepping_ = false;
    SetStepping();
  }
  process_breakpoints_.UpdateBreakpoints();
}

void DebugInfo::ClearBytecodeBreaks() {
  ScopedLock lock(breakpoint_mutex);
  for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
    ClearBytecodeBreak(static_cast<Opcode>(i));
  }
}

}  // namespace dartino

#endif  // DARTINO_ENABLE_LIVE_CODING
