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
//   |   BCP (return) |    |
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
        size_(-1) { }

  bool MovePrevious() {
    Object** current_frame_pointer = frame_pointer_;
    frame_pointer_ = PreviousFramePointer();
    if (frame_pointer_ == NULL) return false;
    size_ = current_frame_pointer - frame_pointer_;
    return true;
  }

  uint8* ByteCodePointer() const {
    return reinterpret_cast<uint8*>(*(frame_pointer_ + size_ - 1));
  }

  Object** FramePointer() const {
    return frame_pointer_;
  }

  // Read the return address from the beginning of the frame.
  uint8* ReturnAddress() const {
    return reinterpret_cast<uint8*>(*(frame_pointer_ - 1));
  }

  // Read the previous frame pointer from the beginning of the frame.
  Object** PreviousFramePointer() const {
    return reinterpret_cast<Object**>(*frame_pointer_);
  }

  Function* FunctionFromByteCodePointer(
      int* frame_ranges_offset_result = NULL) const {
    uint8* bcp = ByteCodePointer();
    return Function::FromBytecodePointer(bcp, frame_ranges_offset_result);
  }

  int FirstLocalIndex() const {
    return (frame_pointer_ - stack_->Pointer(0)) + 2;
  }

  Object** FirstLocalAddress() const {
    return FramePointer() + 2;
  }

  Object** LastLocalAddress() const {
    return FramePointer() + size_ - 2;
  }

 private:
  Stack* stack_;
  Object** frame_pointer_;
  word size_;
};

}  // namespace fletch


#endif  // SRC_VM_FRAME_H_
