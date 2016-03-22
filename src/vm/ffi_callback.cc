// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/ffi_callback.h"

#include "src/vm/frame.h"
#include "src/vm/interpreter.h"
#include "src/vm/scheduler.h"

namespace dartino {

// Allocates a fresh coroutine. May run GCs.
//
// Uses the existing coroutine to keep allocated objects alive while running
// GCs.
static Object* AllocateCoroutine(Process* process) {
  Object* raw_stack = process->NewStack(Process::kInitialStackSize);
  // Retry on allocation failure.
  if (raw_stack->IsRetryAfterGCFailure()) {
    process->program()->CollectNewSpace();
    raw_stack = process->NewStack(Process::kInitialStackSize);
    if (raw_stack->IsRetryAfterGCFailure()) {
      process->program()->CollectNewSpace();
      raw_stack = process->NewStack(Process::kInitialStackSize);
    }
  }
  if (raw_stack->IsRetryAfterGCFailure()) return raw_stack;

  Function* entry = process->entry();
  uint8_t* bcp = entry->bytecode_address_for(0);
  int number_of_arguments = entry->arity();
  ASSERT(number_of_arguments == 7);

  Object* raw_coroutine;
  {
    Stack* stack = Stack::cast(raw_stack);
    Frame frame(stack);

    frame.PushInitialDartEntryFrames(
      number_of_arguments, bcp, reinterpret_cast<Object*>(InterpreterEntry));

    // Temporarily store the stack in the current coroutine.
    // Hold on to the old stack by storing it in the new stack as argument to
    // the entry. This value will be overridden.
    Frame previous_frame(stack);
    previous_frame.MovePrevious();
    *(previous_frame.LastArgumentAddress()) = process->coroutine()->stack();
    process->coroutine()->set_stack(stack);
    // We have linked the stacks. If we happen to have another GC we won't lose
    // the newly allocated stack.

    raw_coroutine = process->NewInstance(process->program()->coroutine_class());
    // Retry on allocation failure.
    if (raw_coroutine->IsRetryAfterGCFailure()) {
      process->program()->CollectNewSpace();
      raw_coroutine =
          process->NewInstance(process->program()->coroutine_class());
      if (raw_coroutine->IsRetryAfterGCFailure()) {
        process->program()->CollectNewSpace();
        raw_coroutine =
            process->NewInstance(process->program()->coroutine_class());
      }
    }
    // Even if we couldn't allocate the coroutine, don't return immediately yet.
    // First undo the stack chaining.
  }
  // Undo the stack chaining and put the original stack back into the
  // coroutine.
  Stack* stack = process->coroutine()->stack();
  Frame previous_frame(stack);
  previous_frame.MovePrevious();

  Stack* original_stack = Stack::cast(*previous_frame.LastArgumentAddress());
  process->coroutine()->set_stack(original_stack);

  if (raw_coroutine->IsRetryAfterGCFailure()) {
    return raw_coroutine;
  }

  // Store the original coroutine in the stack.
  // This is the correct location for the coroutine, since we are passing it
  // to the entry function.
  *previous_frame.LastArgumentAddress() = process->coroutine();

  Coroutine::cast(raw_coroutine)->set_stack(stack);

  return raw_coroutine;
}

static void RestoreOriginalCoroutine(Process* process,
                                     int coroutine_slot_index) {
  Stack* stack = process->coroutine()->stack();

  Coroutine* old_coroutine = Coroutine::cast(stack->get(coroutine_slot_index));
  process->UpdateCoroutine(old_coroutine);
}

static Object* ConvertFfiArgument(word value, Process* process) {
  if (Smi::IsValid(value)) return Smi::FromWord(value);

  Object* result = process->NewInteger(value);
  if (result->IsRetryAfterGCFailure()) {
    process->program()->CollectNewSpace();
    result = process->NewInteger(value);
    if (result->IsRetryAfterGCFailure()) {
      process->program()->CollectNewSpace();
      result = process->NewInteger(value);
    }
  }
  return result;
}

static word DoFfiCallback(int arity, ProcessHandle* process_handle,
                          word callback_id, word arg0, word arg1, word arg2,
                          word error_value) {
  {
    ScopedSpinlock spinlock(process_handle->lock());
    if (process_handle->process() != NULL) {
      ASSERT(process_handle->process()->state() == Process::kRunning);
    } else {
      return error_value;
    }
  }
  Process* process = process_handle->process();
  // We currently assume that the process that is on the stack is the same
  // as the one stored in the process_handle.
  // TODO(floitsch): find the currently active process on the stack.
  Process* old_process = process;

  {
    // Allocate a new coroutine with stack. This may call the GC.
    Object* coroutine = AllocateCoroutine(process);
    // TODO(floitsch): figure out what to do, when we encounter an OOM. For now,
    // just return the error_value.
    if (coroutine->IsRetryAfterGCFailure()) return error_value;
    process->UpdateCoroutine(Coroutine::cast(coroutine));
  }

  int argument_index;
  {
    Frame previous_frame(process->coroutine()->stack());
    previous_frame.MovePrevious();
    argument_index = previous_frame.LastArgumentIndex();
  }
  // The last argument is the old coroutine, which is already set.
  int coroutine_slot_index = argument_index;
  argument_index++;

  int return_slot_index;
  {
    Object* converted_error_value = ConvertFfiArgument(error_value, process);
    if (converted_error_value->IsRetryAfterGCFailure()) {
      RestoreOriginalCoroutine(process, coroutine_slot_index);
      return error_value;
    }
    // The next argument is the return slot.
    // Store the error value in it, so that we have a uniform way of reading
    // the return value when the Dart function returns.
    return_slot_index = argument_index;
    process->coroutine()->stack()->set(argument_index++, converted_error_value);
  }

  if (arity >= 3) {
    Object* converted_arg = ConvertFfiArgument(arg2, process);
    if (converted_arg->IsRetryAfterGCFailure()) {
      RestoreOriginalCoroutine(process, coroutine_slot_index);
      return error_value;
    }
    process->coroutine()->stack()->set(argument_index, converted_arg);
  }
  argument_index++;

  if (arity >= 2) {
    Object* converted_arg = ConvertFfiArgument(arg1, process);
    if (converted_arg->IsRetryAfterGCFailure()) {
      RestoreOriginalCoroutine(process, coroutine_slot_index);
      return error_value;
    }
    process->coroutine()->stack()->set(argument_index, converted_arg);
  }
  argument_index++;

  if (arity >= 1) {
    Object* converted_arg = ConvertFfiArgument(arg0, process);
    if (converted_arg->IsRetryAfterGCFailure()) {
      RestoreOriginalCoroutine(process, coroutine_slot_index);
      return error_value;
    }
    process->coroutine()->stack()->set(argument_index, converted_arg);
  }
  argument_index++;

  {
    Stack* stack = process->coroutine()->stack();
    ASSERT(Smi::IsValid(arity));
    stack->set(argument_index++, Smi::FromWord(arity));

    ASSERT(Smi::IsValid(callback_id));
    stack->set(argument_index++, Smi::FromWord(callback_id));
  }

  Scheduler* scheduler = old_process->scheduler();
  scheduler->InterpretNestedProcess(old_process, process);

  word return_value =
      AsForeignWord(process->coroutine()->stack()->get(return_slot_index));

  RestoreOriginalCoroutine(process, coroutine_slot_index);

  return return_value;
}

// Forward declarations of the callback functions.
FFI_CALLBACKS_DO(DECLARE_CALLBACK_STUB_0_N, \
                 DECLARE_CALLBACK_STUB_1_N, \
                 DECLARE_CALLBACK_STUB_2_N, \
                 DECLARE_CALLBACK_STUB_3_N)

// The array of [CallbackStub] structs.
DEFINE_CALLBACK_STUB_ARRAY

// The definitions of the callback functions.
FFI_CALLBACKS_DO(DEFINE_CALLBACK_STUB_0_N, \
                 DEFINE_CALLBACK_STUB_1_N, \
                 DEFINE_CALLBACK_STUB_2_N, \
                 DEFINE_CALLBACK_STUB_3_N)



BEGIN_LEAF_NATIVE(AllocateFunctionPointer) {
  word arity = AsForeignWord(arguments[0]);
  word callback_id = AsForeignWord(arguments[1]);
  word error_return_value = AsForeignWord(arguments[2]);

  Object* cached_integer = process->EnsureLargeIntegerIsAvailable();
  if (cached_integer->IsRetryAfterGCFailure()) return cached_integer;

  ProcessHandle* process_handle = process->process_handle();

  word result_address = -1;

  int arity_count = sizeof(ffi_stubs) / sizeof(ffi_stubs[0]);
  int stubs_per_arity = sizeof(ffi_stubs[0]) / sizeof(CallbackStub);

  if (arity < 0 || arity > arity_count) return Smi::FromWord(-1);

  for (int i = 0; i < stubs_per_arity; i++) {
    CallbackStub& data = ffi_stubs[arity][i];
    if (data.handle == NULL) {
      process_handle->IncrementRef();
      data.handle = process_handle;
      data.callback_id = callback_id;
      data.error_value = error_return_value;
      result_address = reinterpret_cast<word>(data.function);
      break;
    }
  }

  if (Smi::IsValid(result_address)) {
    return Smi::FromWord(result_address);
  }
  LargeInteger* result = process->ConsumeLargeInteger();
  result->set_value(result_address);
  return result;
}
END_NATIVE()

BEGIN_LEAF_NATIVE(FreeFunctionPointer) {
  word address = AsForeignWord(arguments[0]);

  word callback_id = -1;
  int arity_count = sizeof(ffi_stubs) / sizeof(ffi_stubs[0]);
  int stubs_per_arity = sizeof(ffi_stubs[0]) / sizeof(CallbackStub);
  for (int i = 0; i < arity_count; i++) {
    for (int j = 0; j < stubs_per_arity; j++) {
      CallbackStub& data = ffi_stubs[i][j];
      if (reinterpret_cast<word>(data.function) == address) {
        ProcessHandle::DecrementRef(data.handle);
        data.handle = NULL;
        callback_id = data.callback_id;
        data.error_value = -1;
        break;
      }
    }
    if (callback_id != -1) break;
  }
  return Smi::FromWord(callback_id);
}
END_NATIVE()

#undef FFI_CALLBACKS_DO

}  // namespace dartino
