// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_NATIVE_INTERPRETER_H_
#define SRC_VM_NATIVE_INTERPRETER_H_

namespace fletch {

class Process;
class TargetYieldResult;

#if defined(FLETCH_TARGET_IA32) || defined(FLETCH_TARGET_ARM)

// For the platforms that have a native interpreter this function is
// generated as the native interpreter entry point. The native
// interpreter can bailout to the slower C++ interpreter by returning
// -1.
extern "C" int InterpretFast(Process* process,
                             TargetYieldResult* target_yield_result);

#else

// For the platforms that do not have a native interpreter we bailout
// by returning -1 whenever we attempt to use the native
// interpreter. The slower C++ interpreter will then be used for the
// rest of the interpretation for this process (until it yields or is
// interrupted).
int InterpretFast(Process* process, TargetYieldResult* target_yield_result) {
  return -1;
}

#endif  // defined(FLETCH_TARGET_IA32) || defined(FLETCH_TARGET_ARM)

}  // namespace fletch

#endif  // SRC_VM_NATIVE_INTERPRETER_H_
