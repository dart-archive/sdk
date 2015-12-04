// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_IA32) || defined(FLETCH_TARGET_ARM)

#include "src/vm/native_interpreter.h"

namespace fletch {

extern "C"
uword InterpretFast_DispatchTable[];

extern "C"
void BC_InvokeStatic();

extern "C"
void Debug_BC_InvokeStatic();

const uword kDebugDiff = reinterpret_cast<uword>(BC_InvokeStatic) -
    reinterpret_cast<uword>(Debug_BC_InvokeStatic);

void SetBytecodeBreak(Opcode opcode) {
  uword value = InterpretFast_DispatchTable[opcode];
  if ((value & 2) == 0) {
    InterpretFast_DispatchTable[opcode] = value - kDebugDiff;
  }
}

void ClearBytecodeBreak(Opcode opcode) {
  uword value = InterpretFast_DispatchTable[opcode];
  if ((value & 2) != 0) {
    InterpretFast_DispatchTable[opcode] = value + kDebugDiff;
  }
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_IA32) || defined(FLETCH_TARGET_ARM)
