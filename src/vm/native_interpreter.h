// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_NATIVE_INTERPRETER_H_
#define SRC_VM_NATIVE_INTERPRETER_H_

#include "src/shared/bytecodes.h"

namespace fletch {

class Process;
class TargetYieldResult;

// For the platforms that have a native interpreter this function is
// generated as the native interpreter entry point. The native
// interpreter can bailout to the slower C++ interpreter by returning
// -1.
extern "C" int Interpret(Process* process,
                         TargetYieldResult* target_yield_result);

extern "C" void InterpreterEntry();

extern "C" void InterpreterCoroutineEntry();

extern "C" void InterpreterMethodEntry();

extern "C" void CodegenCoroutineEntry();

__attribute__((weak)) void CodegenCoroutineEntry() {
}

void SetBytecodeBreak(Opcode opcode);

void ClearBytecodeBreak(Opcode opcode);

}  // namespace fletch

#endif  // SRC_VM_NATIVE_INTERPRETER_H_
