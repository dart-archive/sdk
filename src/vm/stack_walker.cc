// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/stack_walker.h"

#include "src/shared/bytecodes.h"
#include "src/shared/selectors.h"
#include "src/shared/utils.h"

#include "src/vm/program.h"
#include "src/vm/session.h"

namespace fletch {

bool StackWalker::MoveNext() {
  int bcp_offset = stack_->top() + stack_offset_;
  uint8* bcp = reinterpret_cast<uint8*>(stack_->get(bcp_offset));

  // At bottom.
  if (bcp == NULL) {
    function_ = NULL;
    return_address_ = NULL;
    frame_size_ = -1;
    frame_ranges_offset_ = -1;
    return false;
  }

  ASSERT(process_->program()->heap()->space()->Includes(
      reinterpret_cast<uword>(bcp)));

  return_address_ = bcp;
  bool first = function_ == NULL;
  function_ = Function::FromBytecodePointer(bcp, &frame_ranges_offset_);
  frame_size_ = ComputeStackOffset(bcp, first);
  stack_offset_ -= (frame_size_ + 1);

  return true;
}

int StackWalker::CookFrame() {
  uint8* start = function_->bytecode_address_for(0);
  stack_->set(stack_->top() + stack_offset_ + frame_size_ + 1, function_);
  return return_address_ - start;
}

void StackWalker::UncookFrame(int delta) {
  Object* current = stack_->get(stack_->top() + stack_offset_);
  if (current == NULL) return;
  Function* function = Function::cast(current);
  uint8* start = function->bytecode_address_for(0);
  Object* bcp = reinterpret_cast<Object*>(start + delta);
  stack_->set(stack_->top() + stack_offset_, bcp);
}

Object** StackWalker::PointerToFirstFrameElement() {
  return stack_->Pointer(stack_->top() + stack_offset_ + 1);
}

Object** StackWalker::PointerToLastFrameElement() {
  return stack_->Pointer(stack_->top() + stack_offset_ + frame_size_);
}

void StackWalker::VisitPointersInFrame(PointerVisitor* visitor) {
  visitor->VisitBlock(PointerToFirstFrameElement(),
                      PointerToLastFrameElement() + 1);
}

Object* StackWalker::GetLocal(int slot) {
  int stack_index = stack_->top() + stack_offset_ + 1 + slot;
  return stack_->get(stack_index);
}

void StackWalker::RestartCurrentFrame() {
  int bcp_offset = stack_->top() + stack_offset_;
  uint8* return_bcp = reinterpret_cast<uint8*>(stack_->get(bcp_offset));
  uint8* previous_bcp = return_bcp - Bytecode::Size(Opcode::kInvokeStatic);
  ASSERT(previous_bcp == Bytecode::PreviousBytecode(return_bcp));
  ASSERT(Bytecode::IsInvoke(static_cast<Opcode>(*previous_bcp)));
  stack_->set(bcp_offset, reinterpret_cast<Object*>(previous_bcp));
  stack_->set_top(bcp_offset);
}

int StackWalker::StackDiff(uint8** bcp,
                           uint8* end_bcp,
                           int current_stack_offset,
                           bool include_last) {
  Program* program = process_->program();
  int stack_diff = kVarDiff;

  Opcode opcode = static_cast<Opcode>(**bcp);
  switch (opcode) {
    case kInvokeMethod:
    case kInvokeMethodVtable: {
      int selector = Utils::ReadInt32(*bcp + 1);
      int arity = Selector::ArityField::decode(selector);
      stack_diff = -arity;
      break;
    }

    case kInvokeMethodFast: {
      int index = Utils::ReadInt32(*bcp + 1);
      Array* table = program->dispatch_table();
      int selector = Smi::cast(table->get(index + 1))->value();
      int arity = Selector::ArityField::decode(selector);
      stack_diff = -arity;
      break;
    }

    case kInvokeStatic:
    case kInvokeFactory: {
      int method = Utils::ReadInt32(*bcp + 1);
      Function* function = program->static_method_at(method);
      stack_diff = 1 - function->arity();
      break;
    }

    case kInvokeStaticUnfold:
    case kInvokeFactoryUnfold: {
      Function* function = Function::cast(Function::ConstantForBytecode(*bcp));
      stack_diff = 1 - function->arity();
      break;
    }

    case kBranchWide:
    case kBranchIfTrueWide:
    case kBranchIfFalseWide: {
      int delta = Utils::ReadInt32(*bcp + 1);
      stack_diff = Bytecode::StackDiff(opcode);
      uint8* target = *bcp + delta;
      if (target < end_bcp || (include_last && target == end_bcp)) {
        *bcp = target;
        // Return as we have moved bcp with a custom delta.
        return stack_diff;
      }
      break;
    }

    case kSubroutineCall: {
      int delta = Utils::ReadInt32(*bcp + 1);
      if (*bcp + delta <= end_bcp) {
        *bcp += delta;
        return 1;
      }
      stack_diff = 0;
      break;
    }

    case kAllocate:
    case kAllocateImmutable: {
      int class_id = Utils::ReadInt32(*bcp + 1);
      Class* klass = program->class_at(class_id);
      int fields = klass->NumberOfInstanceFields();
      stack_diff = 1 - fields;
      break;
    }

    case kAllocateUnfold:
    case kAllocateImmutableUnfold: {
      Class* klass = Class::cast(Function::ConstantForBytecode(*bcp));
      int fields = klass->NumberOfInstanceFields();
      stack_diff = 1 - fields;
      break;
    }

    case kFrameSize: {
      stack_diff = (*bcp)[1] - current_stack_offset;
      break;
    }

    default:
      ASSERT(opcode < Bytecode::kNumBytecodes);
      stack_diff = Bytecode::StackDiff(opcode);
      break;
  }
  ASSERT(stack_diff != kVarDiff);
  *bcp += Bytecode::Size(opcode);
  return stack_diff;
}

int StackWalker::ComputeStackOffset(uint8* end_bcp, bool include_last) {
  int stack_offset = 0;
  uint8* bcp = function_->bytecode_address_for(0);
  if (bcp == end_bcp) return 0;

  // The noSuchMethod trampoline does not contain any catch-blocks and has
  // a dynamic height. Skip it by finding the sentinel value on the stack.
  if (*bcp == Opcode::kEnterNoSuchMethod) {
    int stack_start = stack_->top() + stack_offset_;
    int offset = stack_start;
    while (stack_->get(offset) != process_->program()->sentinel_object()) {
      offset--;
    }
    return stack_start - offset;
  }

  int next_diff = 0;
  while (bcp != end_bcp) {
    ASSERT(bcp < end_bcp);
    stack_offset += next_diff;
    next_diff = StackDiff(&bcp, end_bcp, stack_offset, include_last);
  }
  ASSERT(bcp == end_bcp);
  if (include_last) stack_offset += next_diff;
  ASSERT(stack_offset >= 0);
  return stack_offset;
}

uint8* StackWalker::ComputeCatchBlock(Process* process, int* stack_delta) {
  int delta = 0;
  StackWalker walker(process, process->stack());
  while (walker.MoveNext()) {
    Function* function = walker.function();
    delta += 1 + walker.frame_size();
    int offset = walker.frame_ranges_offset();
    uint8* range_bcp = function->bytecode_address_for(offset);
    int count = Utils::ReadInt32(range_bcp);
    range_bcp += 4;
    for (int i = 0; i < count; i++) {
      int start = Utils::ReadInt32(range_bcp);
      uint8* start_address = function->bytecode_address_for(start);
      range_bcp += 4;
      int end = Utils::ReadInt32(range_bcp);
      uint8* end_address = function->bytecode_address_for(end);
      range_bcp += 4;
      uint8* return_address = walker.return_address();
      if (start_address < return_address && end_address > return_address) {
        // The first hit is the one we use (due to the order they are
        // emitted).
        delta -= walker.ComputeStackOffset(end_address, true);
        *stack_delta = delta;
        return end_address;
      }
    }
  }
  return NULL;
}

void StackWalker::PushFrameOnSessionStack(Session* session, bool isFirstFrame) {
  uint8* start_bcp = function()->bytecode_address_for(0);
  int bytecode_offset = return_address() - start_bcp;
  // The first byte-code offset is not a return address but the offset for
  // the current bytecode. Make it look like a return address by adding
  // the current bytecode size to the byte-code offset.
  if (isFirstFrame) {
    Opcode current = static_cast<Opcode>(*return_address());
    bytecode_offset += Bytecode::Size(current);
  }
  session->PushNewInteger(bytecode_offset);
  session->PushFunction(function());
}

int StackWalker::ComputeStackTrace(Process* process,
                                   Stack* stack,
                                   Session* session) {
  int frames = 0;
  StackWalker walker(process, stack);
  while (walker.MoveNext()) {
    walker.PushFrameOnSessionStack(session, frames == 0);
    ++frames;
  }
  return frames;
}

void StackWalker::ComputeTopStackFrame(Process* process, Session* session) {
  StackWalker walker(process, process->stack());
  bool has_top_frame = walker.MoveNext();
  ASSERT(has_top_frame);
  walker.PushFrameOnSessionStack(session, true);
}

void StackWalker::RestartFrame(Process* process, int frame) {
  StackWalker walker(process, process->stack());
  walker.MoveNext();
  for (int i = 0; i < frame; i++) walker.MoveNext();
  return walker.RestartCurrentFrame();
}

Object* StackWalker::ComputeLocal(Process* process, int frame, int slot) {
  StackWalker walker(process, process->stack());
  walker.MoveNext();
  for (int i = 0; i < frame; i++) walker.MoveNext();
  return walker.GetLocal(slot);
}

}  // namespace fletch
