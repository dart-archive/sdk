// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef DARTINO_ENABLE_LIVE_CODING

#include "src/vm/dispatch_table.h"

#include "src/vm/native_interpreter.h"
#include "src/vm/debug_info.h"

namespace dartino {

void DispatchTable::ResetBreakpoints(
    const DebugInfo* debug_info,
    const Breakpoints* program_breakpoints) {
  // If stepping, we don't need to clear any previous state.
  if (debug_info != NULL && debug_info->is_stepping()) {
    SetStepping();
    return;
  }
  // Otherwise, clear and restore global and local breaks in the table.
  ClearAllBreakpoints();
  SetBreakpoints(program_breakpoints);
  if (debug_info != NULL) SetBreakpoints(debug_info->breakpoints());
}

void DispatchTable::SetBreakpoints(const Breakpoints* breakpoints) {
  if (state_ == kStepping || breakpoints->IsEmpty()) return;
  state_ = kDirty;
  for (auto& pair : breakpoints->map()) {
    SetBytecodeBreak(static_cast<Opcode>(*pair.first));
  }
}

void DispatchTable::SetStepping() {
  if (state_ == kStepping) return;
  state_ = kStepping;
  for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
    SetBytecodeBreak(static_cast<Opcode>(i));
  }
}

void DispatchTable::ClearAllBreakpoints() {
  if (state_ == kClean) return;
  state_ = kClean;
  for (int i = 0; i < Bytecode::kNumBytecodes; i++) {
    ClearBytecodeBreak(static_cast<Opcode>(i));
  }
}

}  // namespace dartino

#endif  // DARTINO_ENABLE_LIVE_CODING
