// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/interpreter.h"

#include <math.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/frame.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/natives.h"
#include "src/vm/port.h"
#include "src/vm/process.h"

namespace fletch {

const NativeFunction kNativeTable[] = {
#define N(e, c, n, d) &Native_##e,
    NATIVES_DO(N)
#undef N
};

class State {
 public:
  explicit State(Process* process)
      : process_(process), program_(process->program()) {
    RestoreState();
  }

  Process* process() const { return process_; }
  Program* program() const { return program_; }

  void SaveState() {
    StoreByteCodePointer(bcp_);
    Push(reinterpret_cast<Object*>(resume_address_));
    Push(reinterpret_cast<Object*>(fp_));
    process_->stack()->SetTopFromPointer(sp_);
  }

  void RestoreState() {
    Stack* stack = process_->stack();
    sp_ = stack->Pointer(stack->top());
    fp_ = reinterpret_cast<Object**>(Pop());
    resume_address_ = reinterpret_cast<void*>(Pop());
    bcp_ = LoadByteCodePointer();
    StoreByteCodePointer(NULL);
    ASSERT(bcp_ != NULL);
  }

  // Bytecode pointer related operations.
  uint8 ReadByte(int offset) { return bcp_[offset]; }
  int ReadInt32(int offset) { return Utils::ReadInt32(bcp_ + offset); }

  void Advance(int delta) { bcp_ += delta; }

  Object* Local(int n) { return *(sp_ + n); }
  void SetLocal(int n, Object* value) { *(sp_ + n) = value; }

  Object* Pop() { return *(sp_++); }
  void Push(Object* value) { *(--sp_) = value; }
  void Drop(int n) { sp_ += n; }

  void StoreByteCodePointer(uint8* bcp) {
    *(fp_ - 1) = reinterpret_cast<Object*>(bcp);
  }

  uint8* LoadByteCodePointer() { return reinterpret_cast<uint8*>(*(fp_ - 1)); }

  Object** fp() { return fp_; }

 protected:
  uint8* bcp() { return bcp_; }
  Object** sp() { return sp_; }

 private:
  Process* const process_;
  Program* const program_;
  Object** sp_;
  Object** fp_;
  uint8* bcp_;
  void* resume_address_;
};

void Interpreter::Run() {
  ASSERT(interruption_ == kReady);

  // TODO(ager): We might want to have a stack guard check here in
  // order to make sure that all interruptions active at a certain
  // stack guard check gets handled at the same bcp.

  process_->RestoreErrno();
  process_->TakeLookupCache();

  // Whenever we enter the interpreter, we might operate on a stack which
  // doesn't contain any references to new space. This means the remembered set
  // might *NOT* contain the stack.
  //
  // Since we don't update the remembered set on every mutating operation - e.g.
  // SetLocal() - we add it as soon as the interpreter uses it:
  //   * once we enter the interpreter
  //   * once we we're done with mutable GC
  //   * once we we've done a coroutine change
  // This is conservative.
  process_->remembered_set()->Insert(process_->stack());

  int result = Interpret(process_, &target_yield_result_);
  if (result < 0) FATAL("Fatal error in native interpreter");
  interruption_ = static_cast<InterruptKind>(result);

  process_->ReleaseLookupCache();
  process_->StoreErrno();
  ASSERT(interruption_ != kReady);
}

// -------------------- Native interpreter support --------------------

Process::StackCheckResult HandleStackOverflow(Process* process, int size) {
  return process->HandleStackOverflow(size);
}

void HandleGC(Process* process) {
  if (process->heap()->needs_garbage_collection()) {
    process->program()->CollectNewSpace();

    // After a mutable GC a lot of stacks might no longer have pointers to
    // new space on them. If so, the remembered set will no longer contain such
    // a stack.
    //
    // Since we don't update the remembered set on every mutating operation
    // - e.g. SetLocal() - we add it before we start using it.
    process->remembered_set()->Insert(process->stack());
  }
}

Object* HandleObjectFromFailure(Process* process, Failure* failure) {
  return process->program()->ObjectFromFailure(failure);
}

Object* HandleAllocate(Process* process, Class* clazz, int immutable) {
  Object* result = process->NewInstance(clazz, immutable == 1);
  if (result->IsFailure()) return result;
  return result;
}

void AddToStoreBufferSlow(Process* process, Object* object, Object* value) {
  ASSERT(object->IsHeapObject());
  ASSERT(
      process->heap()->space()->Includes(HeapObject::cast(object)->address()));
  if (value->IsHeapObject()) {
    process->remembered_set()->Insert(HeapObject::cast(object));
  }
}

Object* HandleAllocateBoxed(Process* process, Object* value) {
  Object* boxed = process->NewBoxed(value);
  if (boxed->IsFailure()) return boxed;

  if (value->IsHeapObject() && !value->IsNull()) {
    process->remembered_set()->Insert(HeapObject::cast(boxed));
  }
  return boxed;
}

void HandleCoroutineChange(Process* process, Coroutine* coroutine) {
  process->UpdateCoroutine(coroutine);
}

Object* HandleIdentical(Process* process, Object* left, Object* right) {
  bool identical;
  if (left == right) {
    identical = true;
  } else if (left->IsDouble() && right->IsDouble()) {
    fletch_double_as_uint left_value =
        bit_cast<fletch_double_as_uint>(Double::cast(left)->value());
    fletch_double_as_uint right_value =
        bit_cast<fletch_double_as_uint>(Double::cast(right)->value());
    identical = (left_value == right_value);
  } else if (left->IsLargeInteger() && right->IsLargeInteger()) {
    int64 left_value = LargeInteger::cast(left)->value();
    int64 right_value = LargeInteger::cast(right)->value();
    identical = (left_value == right_value);
  } else {
    identical = false;
  }
  Program* program = process->program();
  return identical ? program->true_object() : program->false_object();
}

LookupCache::Entry* HandleLookupEntry(Process* process,
                                      LookupCache::Entry* primary, Class* clazz,
                                      int selector) {
  // TODO(kasperl): Can we inline the definition here? This is
  // performance critical.
  return process->LookupEntrySlow(primary, clazz, selector);
}

// Overlay this struct on the catch table to interpret the bytes.
struct CatchBlock {
  int start;
  int end;
  int frame_size;
};

static uint8* FindCatchBlock(Stack* stack, int* stack_delta_result,
                             Object*** frame_pointer_result) {
  Frame frame(stack);
  while (frame.MovePrevious()) {
    int offset = -1;
    Function* function = frame.FunctionFromByteCodePointer(&offset);
    // Skip frames with no byte code pointer / function.
    if (function == NULL) continue;

    // Skip if there are no catch blocks.
    if (offset == -1) continue;

    uint8* bcp = frame.ByteCodePointer();
    uint8* catch_block_address = function->bytecode_address_for(offset);
    int count = Utils::ReadInt32(catch_block_address);
    const CatchBlock* block =
        reinterpret_cast<const CatchBlock*>(catch_block_address + 4);
    for (int i = 0; i < count; i++) {
      uint8* start_address = function->bytecode_address_for(block->start);
      uint8* end_address = function->bytecode_address_for(block->end);
      // The first hit is the one we use (due to the order they are
      // emitted).
      if (start_address <= bcp && end_address > bcp) {
        // Read the number of stack slots we need to pop.
        int index = frame.FirstLocalIndex() - block->frame_size - 1;
        *stack_delta_result = index - stack->top();
        *frame_pointer_result = frame.FramePointer();
        return end_address;
      }
      block++;
    }
  }
  return NULL;
}

uint8* HandleThrow(Process* process, Object* exception, int* stack_delta_result,
                   Object*** frame_pointer_result) {
  void* resume_address = Frame(process->stack()).ReturnAddress();
  Coroutine* current = process->coroutine();
  while (true) {
    // If we find a handler, we do a 2nd pass, unwind all coroutine stacks
    // until the handler, make the unused coroutines/stacks GCable and return
    // the handling bcp.
    uint8* catch_bcp = FindCatchBlock(current->stack(), stack_delta_result,
                                      frame_pointer_result);
    if (catch_bcp != NULL) {
      Coroutine* unused = process->coroutine();
      while (current != unused) {
        Coroutine* caller = unused->caller();
        unused->set_stack(process->program()->null_object());
        unused->set_caller(unused);
        unused = caller;
      }
      process->UpdateCoroutine(current);
      Frame(process->stack()).SetReturnAddress(resume_address);
      return catch_bcp;
    }

    if (!current->has_caller()) {
      break;
    }
    current = current->caller();
  }

  // If we haven't found a handler we leave the coroutine/stacks untouched and
  // signal that the exception was uncaught.
  process->set_exception(exception);
  return NULL;
}

void HandleEnterNoSuchMethod(Process* process) {
  Frame caller_frame(process->stack());

  // Navigate to the the frame that invoked the unresolved call.
  caller_frame.MovePrevious();
  caller_frame.MovePrevious();

  // TODO(ajohnsen): Make this work in a non-restored state?
  State state(process);

  Program* program = state.program();

  // Read the bcp address for the frame.
  uint8* bcp = caller_frame.ByteCodePointer();
  Opcode opcode = static_cast<Opcode>(*bcp);

  int selector;
  if (opcode == Opcode::kInvokeSelector) {
    // If we have nested noSuchMethod trampolines, the selector is located
    // in the caller frame, as the first argument.
    int call_selector = Smi::cast(*caller_frame.FirstLocalAddress())->value();

    // The selector that was used was not this selector, but instead a 'call'
    // selector with the same arity (see call_selector below).
    int arity = Selector::ArityField::decode(call_selector);
    selector = Selector::EncodeMethod(Names::kCall, arity);
  } else if (opcode == Opcode::kInvokeNoSuchMethod) {
    selector = Utils::ReadInt32(bcp + 1);
  } else if (Bytecode::IsInvoke(opcode)) {
    selector = Utils::ReadInt32(bcp + 1);
    int offset = Selector::IdField::decode(selector);
    for (int i = offset; true; i++) {
      DispatchTableEntry* entry = DispatchTableEntry::cast(
          program->dispatch_table()->get(i));
      if (entry->offset()->value() == offset) {
        selector = entry->selector();
        break;
      }
    }
  } else {
    ASSERT(Bytecode::IsInvokeUnfold(opcode));
    selector = Utils::ReadInt32(bcp + 1);
  }

  int arity = Selector::ArityField::decode(selector);
  Smi* selector_smi = Smi::FromWord(selector);
  Object* receiver = state.Local(arity + 3);

  Class* clazz = receiver->IsSmi() ? program->smi_class()
                                   : HeapObject::cast(receiver)->get_class();

  // This value is used by exitNoSuchMethod to pop arguments and detect if
  // original selector was a setter.
  state.Push(selector_smi);

  int selector_id = Selector::IdField::decode(selector);
  int get_selector = Selector::EncodeGetter(selector_id);

  if (clazz->LookupMethod(get_selector) != NULL &&
      !clazz->IsSubclassOf(program->closure_class())) {
    int call_selector = Selector::EncodeMethod(Names::kCall, arity);
    state.Push(Smi::FromWord(call_selector));
    state.Push(Smi::FromWord(get_selector));
    state.Push(program->null_object());
    for (int i = 0; i < arity; i++) {
      state.Push(state.Local(arity + 6));
    }
    state.Push(program->null_object());
    state.Push(receiver);
    state.Advance(kEnterNoSuchMethodLength);
  } else {
    // Prepare for no such method. The code for invoking noSuchMethod is
    // located at the delta specified in the bytecode argument.
    state.Push(receiver);

    // These 3 arguments are passed to
    //     lib/core/core_patch.dart:Object._noSuchMethod()
    //
    // The number of arguments must be kept in sync with
    //     pkg/fletchc/lib/src/fletch_backend.dart:
    //       FletchBackend.codegenExternalNoSuchMethodTrampoline
    state.Push(receiver);
    state.Push(clazz);
    state.Push(selector_smi);
    state.Advance(state.ReadByte(1));
  }

  state.SaveState();
}

Function* HandleInvokeSelector(Process* process) {
  State state(process);

  Object* receiver = state.Pop();
  int selector_slot = state.ReadInt32(1);
  Smi* selector_smi = Smi::cast(*(state.fp() - 2 - selector_slot));
  int selector = selector_smi->value();
  int arity = Selector::ArityField::decode(selector);
  state.SetLocal(arity, receiver);

  Class* clazz = receiver->IsSmi() ? state.program()->smi_class()
                                   : HeapObject::cast(receiver)->get_class();
  Function* target = clazz->LookupMethod(selector);
  if (target == NULL) {
    static const Names::Id name = Names::kNoSuchMethodTrampoline;
    target = clazz->LookupMethod(Selector::Encode(name, Selector::METHOD, 0));
  }

  state.SaveState();
  return target;
}

int HandleAtBytecode(Process* process, uint8* bcp, Object** sp) {
  // TODO(ajohnsen): Support validate stack.
  DebugInfo* debug_info = process->debug_info();
  if (debug_info != NULL) {
    // If we already are at the breakpoint, just clear it (to support stepping).
    if (debug_info->is_at_breakpoint()) {
      debug_info->ClearBreakpoint();
    } else if (debug_info->ShouldBreak(bcp, sp)) {
      return Interpreter::kBreakPoint;
    }
  }
  return Interpreter::kReady;
}

}  // namespace fletch
