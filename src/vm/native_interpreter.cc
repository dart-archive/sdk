// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include "src/vm/native_interpreter.h"

namespace fletch {

extern "C"
uword Interpret_DispatchTable[];

extern "C"
void BC_InvokeStatic();

extern "C"
void Debug_BC_InvokeStatic();

const uword kDebugDiff = reinterpret_cast<uword>(BC_InvokeStatic) -
    reinterpret_cast<uword>(Debug_BC_InvokeStatic);

void SetBytecodeBreak(Opcode opcode) {
  ASSERT((reinterpret_cast<uword>(Debug_BC_InvokeStatic) & 0x4) == 4);
  ASSERT((reinterpret_cast<uword>(BC_InvokeStatic) & 0x4) == 0);

  uword value = Interpret_DispatchTable[opcode];
  if ((value & 4) == 0) {
    Interpret_DispatchTable[opcode] = value - kDebugDiff;
  }
}

void ClearBytecodeBreak(Opcode opcode) {
  uword value = Interpret_DispatchTable[opcode];
  if ((value & 4) != 0) {
    Interpret_DispatchTable[opcode] = value + kDebugDiff;
  }
}

}  // namespace fletch
