// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_FRAME_H_
#define SRC_VM_FRAME_H_

#include "src/shared/globals.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace dartino {

// General stack layout:
//
//  Growing down:
//
//  |                |
//  |  Frame pointer |<--+
//  |                |   |
//  +----------------+   |
//  |                |   |
//  |                |   |
//  +----------------+   |
//  |       .        |   |
//  |       .        |   |
//  |       .        |   |
//  |   Arguments    |   |
//  +----------------+   |
//  | Return address |   |
//  | Frame pointer  +---+   <--- FramePointer()
//  |      BCP       |
//  +----------------+
//  |       .        |
//  |       .        |
//  |       .        |
//  |    Locals      |
//  +----------------+
//  |                |
//
// A frame is used to navigate a stack, frame by frame.
//
// The return-address slot is usually empty, and is only set, if the stack is
// set up for a restore-state.
//
// Note that the BCP is not always present. In particular, saving the state only
// stores the resume address of the interpreter:
//
// Before `saveState`:                      `after saveState`:
//
//  |   Arguments    |   |                     |   Arguments    |   |
//  +----------------+   |                     +----------------+   |
//  | Return address |   |                     | Return address |   |
//  | Frame pointer  +---+  <-- FramePointer() | Frame pointer  +<--+
//  |      BCP       |                         |      BCP       |   |
//  +----------------+                         +----------------+   |
//  |       .        |                         |       .        |   |
//  |       .        |                         |       .        |   |
//  |    Locals      | <-- stack->top()        |    Locals      |   |
//  +----------------+                         +----------------+   |
//  |                |                         | Resume address |   |
//                             stack->top()--> | Frame pointer  +---+
//                           FramePointer()
//
// Note: `stack->top()` points to the index of the slot, whereas
// `FramePointer()` points to the address of the stack.
//
// After `saveState()`, `stack->top()` and `FramePointer()` point to the same
// slot. The return-address slot, is used as resume-address, where the
// interpreter should continue when restoring the state.
//
// Note: a `saveState()` also updates the BCP slot of the current frame.
class Frame {
 public:
  explicit Frame(Stack* stack)
      : stack_(stack),
        frame_pointer_(stack->Pointer(stack->top())),
        size_(-1) {}

  // Creates the initial frames for a fresh stack.
  //
  // Adds three frames: a sentinel frame, and a frame supporting
  // [number_of_arguments] arguments, which are the arguments to the Dart
  // function at [bcp], and the save-state frame.
  //
  // The initial sentinel frame that is initialized to all `NULL`.
  //
  // The second frame is an empty (valid) frame, set up for execution of the
  // the Dart function at [bcp].
  //
  // The third frame is the save-state frame, which is setup so that a
  // `restoreState()` can continue (or start) the Dart function at [bcp].
  //
  // When this function returns, the stack top is set to the frame pointer of
  // the third frame.
  void PushInitialDartEntryFrames(int number_of_arguments, uint8_t* bcp,
                                  void* start_address) {
    ASSERT(stack_->top() == 0);

    PushSentinelFrame();
    int number_of_locals = 0;
    PushFrame(number_of_arguments, number_of_locals);
    PushSafePoint(bcp, start_address);
  }

  // Installs a sentinel frame.
  //
  // The return-address, the previous-framepointer and the bcp-slot are set to
  // 0.
  //
  // Updates the frame pointer, and the stack's top. The top includes space for
  // the bcp..
  void PushSentinelFrame() {
    word top = stack_->length();

    // Return-address.
    stack_->set(--top, NULL);
    // Push previous frame-pointer, and update the frame-pointer field.
    stack_->set(--top, NULL);
    frame_pointer_ = stack_->Pointer(top);
    // Push BCP.
    stack_->set(--top, NULL);
    stack_->set_top(top);
  }

  // Pushes a new frame onto the stack.
  //
  // Initializes [number_of_arguments] arguments and [number_of_locals] locals
  // to 0.
  //
  // The return address and bcp of the new frame are initialized to 0.
  //
  // Updates the frame pointer and the stack's top.
  void PushFrame(int number_of_arguments, int number_of_locals) {
    word top = stack_->top();
    // Push the arguments.
    for (int i = 0; i < number_of_arguments; i++) {
      stack_->set(--top, reinterpret_cast<Object*>(Smi::zero()));
    }
    // Push the return-address.
    stack_->set(--top, NULL);
    // Push the previous frame pointer and update the frame-pointer field.
    stack_->set(--top, reinterpret_cast<Object*>(FramePointer()));
    frame_pointer_ = stack_->Pointer(top);
    // Push NULL as bcp.
    stack_->set(--top, NULL);
    // Push the locals.
    for (int i = 0; i < number_of_locals; i++) {
      stack_->set(--top, reinterpret_cast<Object*>(Smi::zero()));
    }
    stack_->set_top(top);
  }

  // Prepares the current stack for a restore-state action.
  //
  // Updates the current frame with the given [bcp], pushes a new frame, and
  // stores the [resume_address] as return-address of the new frame.
  //
  // A restore-state will execute the resume_address, continuing at the given
  // bcp.
  //
  // See `interpreter_X.cc` for `restoreState`.
  void PushSafePoint(uint8_t* bcp, void* resume_address) {
    ASSERT(stack_->top() != 0);

    SetByteCodePointer(bcp);

    // Don't use [PushFrame], because we don't need to push the bcp slot.
    word top = stack_->top();
    stack_->set(--top, reinterpret_cast<Object*>(resume_address));
    stack_->set(--top, reinterpret_cast<Object*>(FramePointer()));
    frame_pointer_ = stack_->Pointer(top);
    stack_->set_top(top);
  }

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
  //
  // Returns `NULL` if the bcp is `NULL`.
  Function* FunctionFromByteCodePointer(
      int* frame_ranges_offset_result = NULL) const {
    uint8* bcp = ByteCodePointer();
    if (bcp == NULL) return NULL;
    return Function::FromBytecodePointer(bcp, frame_ranges_offset_result);
  }

  word FirstLocalIndex() const {
    return FirstLocalAddress() - stack_->Pointer(0);
  }

  word LastLocalIndex() const {
    return LastLocalAddress() - stack_->Pointer(0);
  }

  word LastArgumentIndex() const {
    return LastArgumentAddress() - stack_->Pointer(0);
  }

  // Returns the address of the first local.
  //
  // The first slot after the frame pointer is reserved for the BCP. Therefore,
  // the first local is at an offset of two.
  Object** FirstLocalAddress() const { return FramePointer() - 2; }

  Object** LastLocalAddress() const { return FramePointer() - size_ + 2; }

  Object** NextFramePointer() const { return FramePointer() - size_; }

  // Returns the address of the last argument.
  //
  // The first slot before the frame pointer is reserved for the return address.
  // Therefore, the last argument is at an offset of two.
  Object** LastArgumentAddress() const { return FramePointer() + 2; }

 private:
  Stack* stack_;
  Object** frame_pointer_;
  word size_;
};

}  // namespace dartino

#endif  // SRC_VM_FRAME_H_
