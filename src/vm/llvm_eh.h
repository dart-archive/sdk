// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LLVM_EH_H_
#define SRC_VM_LLVM_EH_H_

#include <stdint.h>

// System C++ ABI unwind types from
// http://mentorembedded.github.com/cxx-abi/abi-eh.html (v1.22)

typedef enum {
  _URC_NO_REASON = 0,
  _URC_FOREIGN_EXCEPTION_CAUGHT = 1,
  _URC_FATAL_PHASE2_ERROR = 2,
  _URC_FATAL_PHASE1_ERROR = 3,
  _URC_NORMAL_STOP = 4,
  _URC_END_OF_STACK = 5,
  _URC_HANDLER_FOUND = 6,
  _URC_INSTALL_CONTEXT = 7,
  _URC_CONTINUE_UNWIND = 8
} _Unwind_Reason_Code;

typedef enum {
  _UA_SEARCH_PHASE = 1,
  _UA_CLEANUP_PHASE = 2,
  _UA_HANDLER_FRAME = 4,
  _UA_FORCE_UNWIND = 8,
  _UA_END_OF_STACK = 16
} _Unwind_Action;

struct _Unwind_Exception;

typedef void (*_Unwind_Exception_Cleanup_Fn) (_Unwind_Reason_Code, _Unwind_Exception* );

struct _Unwind_Context;
typedef _Unwind_Context* _Unwind_Context_t;

struct _Unwind_Exception {
  uint64_t exception_class;
  _Unwind_Exception_Cleanup_Fn exception_cleanup;
  uintptr_t private_1;
  uintptr_t private_2;
} __attribute__((__aligned__));

namespace dartino {

void ExceptionsSetup();

}  // namespace dartino

#endif // SRC_VM_LLVM_EH_H_