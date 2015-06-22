// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_STACK_WALKER_H_
#define SRC_VM_STACK_WALKER_H_

#include "src/shared/globals.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

// StackWalker that can walk a stack, under a few assumptions:
//  - The TOP of the stack is the current bcp.
//  - The BOTTOM of the stack(last return bcp) is NULL.
//
// A stack walker also acts as a no allocation failure scope.
// The stack walker holds on to a raw pointer to a stack and
// is therefore not GC safe.
class StackWalker {
 public:
  StackWalker(Process* process, Stack* stack)
      : no_allocation_failure_scope_(process->heap()->space()),
        process_(process),
        stack_(stack),
        stack_offset_(0),
        function_(NULL),
        return_address_(NULL),
        frame_size_(-1),
        frame_ranges_offset_(-1) {
  }

  bool MoveNext();

  // Cook the frame by replacing the return address with the
  // function for that bytecode pointer. Return the bytecode
  // pointer as a delta from the first bytecode.
  int CookFrame();

  // Uncook frame given the delta returned by CookFrame.
  void UncookFrame(int delta);

  // Get the local in the given slot. A slot is relative to the value
  // immediately after the return address in the current frame.
  Object* GetLocal(int slot);

  // Manipulate the stack to restart the current frame when process
  // continues.
  void RestartCurrentFrame();

  Function* function() const { return function_; }
  uint8* return_address() const { return return_address_; }
  int frame_size() const { return frame_size_; }
  int frame_ranges_offset() const { return frame_ranges_offset_; }
  int stack_offset() const { return stack_offset_; };

  // Compute the stack offset at [bcp].
  int ComputeStackOffset(uint8* bcp, bool include_last = false);

  // Compute the top catch block.
  static uint8* ComputeCatchBlock(Process* process, int* stack_delta);

  // Compute a stack trace and send it to the session.
  static int ComputeStackTrace(Process* process, Session* session);

  // Manipulate the stack to restart frame |frame| when process continues.
  static void RestartFrame(Process* process, int frame);

  // Compute the value of the local in stack frame |frame| in slot |slot|.
  static Object* ComputeLocal(Process* process, int frame, int slot);

 private:
  int StackDiff(uint8** bcp,
                uint8* end_bcp,
                int current_stack_offset,
                bool include_last);

  NoAllocationFailureScope no_allocation_failure_scope_;
  Process* process_;
  Stack* stack_;
  int stack_offset_;
  Function* function_;
  uint8* return_address_;
  int frame_size_;
  int frame_ranges_offset_;
};

}  // namespace fletch


#endif  // SRC_VM_STACK_WALKER_H_

