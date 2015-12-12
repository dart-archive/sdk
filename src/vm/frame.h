// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_FRAME_H_
#define SRC_VM_FRAME_H_

#include "src/shared/globals.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

// General stack layout:
//
//   |                |
//   +----------------+
//   |    Locals      |
//   |       .        |
//   |       .        |
//   |       .        |
//   +----------------+
//   |     Empty      |
//   |  Frame pointer +----+  <-- FramePointer()
//   |      BCP       |    |
//   +----------------+    |
//   |   Arguments    |    |
//   |       .        |    |
//   |       .        |    |
//   |       .        |    |
//   +----------------+    |
//   |                |    |
//   |                |    |
//   +----------------+    |
//   |                |    |
//   |  Frame pointer | <--+
//   |                |
//
// A frame is used to navigate a stack, frame by frame.
class Frame {
 public:
  explicit Frame(Stack* stack)
      : stack_(stack),
        frame_pointer_(stack->Pointer(stack->top())),
        size_(-1) {}

  bool MovePrevious() {
    Object** current_frame_pointer = frame_pointer_;
    frame_pointer_ = PreviousFramePointer();
    if (frame_pointer_ == NULL) return false;
    size_ = frame_pointer_ - current_frame_pointer;
    return true;
  }

  Object** FramePointer() const { return frame_pointer_; }

  uint8* ByteCodePointer() const {
    return reinterpret_cast<uint8*>(*(frame_pointer_ - 1));
  }

  void SetByteCodePointer(uint8* return_address) {
    *(frame_pointer_ - 1) = reinterpret_cast<Object*>(return_address);
  }

  Object** PreviousFramePointer() const {
    return reinterpret_cast<Object**>(*frame_pointer_);
  }

  void* ReturnAddress() const {
    return reinterpret_cast<void*>(*(frame_pointer_ + 1));
  }

  void SetReturnAddress(void* address) {
    *(frame_pointer_ + 1) = reinterpret_cast<Object*>(address);
  }

  // Find the function of the bcp, by searching through the bytecodes
  // for the MethodEnd bytecode. This operation is linear to the size of the
  // bytecode; O(n).
  Function* FunctionFromByteCodePointer(
      int* frame_ranges_offset_result = NULL) const {
    uint8* bcp = ByteCodePointer();
    return Function::FromBytecodePointer(bcp, frame_ranges_offset_result);
  }

  word FirstLocalIndex() const {
    return FirstLocalAddress() - stack_->Pointer(0);
  }

  word LastLocalIndex() const {
    return LastLocalAddress() - stack_->Pointer(0);
  }

  Object** FirstLocalAddress() const { return FramePointer() - 2; }

  Object** LastLocalAddress() const { return FramePointer() - size_ + 2; }

  Object** NextFramePointer() const { return FramePointer() - size_; }

 private:
  Stack* stack_;
  Object** frame_pointer_;
  word size_;
};

}  // namespace fletch

#endif  // SRC_VM_FRAME_H_
