// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/process.h"

#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/event_handler.h"
#include "src/vm/frame.h"
#include "src/vm/heap_validator.h"
#include "src/vm/mark_sweep.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/natives.h"
#include "src/vm/object_memory.h"
#include "src/vm/port.h"
#include "src/vm/process_queue.h"
#include "src/vm/remembered_set.h"
#include "src/vm/session.h"

namespace fletch {

static uword kPreemptMarker = 1 << 0;
static uword kDebugInterruptMarker = 1 << 1;
static uword kMaxStackMarker = ~static_cast<uword>((1 << 2) - 1);

Process::Process(Program* program, Process* parent)
    : native_stack_(NULL),
      coroutine_(NULL),
      stack_limit_(0),
      program_(program),
      statics_(NULL),
      exception_(program->null_object()),
      primary_lookup_cache_(NULL),
      random_(program->random()->NextUInt32() + 1),
      state_(kSleeping),
      next_(NULL),
      queue_(NULL),
      queue_next_(NULL),
      queue_previous_(NULL),
      signal_(NULL),
      process_handle_(NULL),
      ports_(NULL),
      process_list_next_(NULL),
      process_list_prev_(NULL),
      process_triangle_count_(1),
      parent_(parent),
      errno_cache_(0),
      debug_info_(NULL)
#ifdef DEBUG
      ,
      native_verifier_(NULL)
#endif
{
  process_handle_ = new ProcessHandle(this);

  // These asserts need to hold when running on the target, but they don't need
  // to hold on the host (the build machine, where the interpreter-generating
  // program runs).  We put these asserts here on the assumption that the
  // interpreter-generating program will not instantiate this class.
  static_assert(kNativeStackOffset == offsetof(Process, native_stack_),
                "native_stack_");
  static_assert(kCoroutineOffset == offsetof(Process, coroutine_),
                "coroutine_");
  static_assert(kStackLimitOffset == offsetof(Process, stack_limit_),
                "stack_limit_");
  static_assert(kProgramOffset == offsetof(Process, program_), "program_");
  static_assert(kStaticsOffset == offsetof(Process, statics_), "statics_");
  static_assert(kExceptionOffset == offsetof(Process, exception_),
                "exception_");
  static_assert(
      kPrimaryLookupCacheOffset == offsetof(Process, primary_lookup_cache_),
      "primary_lookup_cache_");

  Array* static_fields = program->static_fields();
  int length = static_fields->length();
  statics_ = Array::cast(NewArray(length));
  for (int i = 0; i < length; i++) {
    statics_->set(i, static_fields->get(i));
  }
#ifdef DEBUG
  true_then_false_ = true;
#endif
}

Process::~Process() {
  // [Cleanup] should've been called at this point. So we ASSERT the post
  // conditions here.
  ASSERT(ports_ == NULL);

  links()->NotifyMonitors(process_handle());

  ProcessHandle::DecrementRef(process_handle_);

  Signal* signal = signal_.load();
  if (signal != NULL) Signal::DecrementRef(signal);

  delete debug_info_;

  ASSERT(next_ == NULL);
}

void Process::Cleanup(Signal::Kind kind) {
  EventHandler* event_handler = EventHandler::GlobalInstance();
  event_handler->ReceiverForPortsDied(ports_);

  // Clear out the process pointer from all the ports.
  while (ports_ != NULL) {
    Port* next = ports_->next();
    ports_->OwnerProcessTerminating();
    ports_ = next;
  }

  // We are going down at this point. If anything else is starting to
  // link/monitor with this [ProcessHandle], it will fail after this line.
  process_handle_->OwnerProcessTerminating();

  // Since nobody can send us messages (or signals) at this point, we send a
  // signal to all linked processes.
  links()->NotifyLinkedProcesses(process_handle(), kind);
}

void Process::SetupExecutionStack() {
  ASSERT(coroutine_ == NULL);
  Stack* stack = Stack::cast(NewStack(256));
  stack->set(0, NULL);
  Coroutine* coroutine =
      Coroutine::cast(NewInstance(program()->coroutine_class()));
  coroutine->set_stack(stack);
  UpdateCoroutine(coroutine);
}

void Process::UpdateCoroutine(Coroutine* coroutine) {
  ASSERT(coroutine->has_stack());
  coroutine_ = coroutine;
  UpdateStackLimit();
  remembered_set_.Insert(coroutine->stack());
}

Process::StackCheckResult Process::HandleStackOverflow(int addition) {
  uword current_limit = stack_limit();

  if (current_limit >= kMaxStackMarker) {
    if ((current_limit & kPreemptMarker) != 0) {
      ClearStackMarker(kPreemptMarker);
      UpdateStackLimit();
      return kStackCheckInterrupt;
    }

    if ((current_limit & kDebugInterruptMarker) != 0) {
      ClearStackMarker(kDebugInterruptMarker);
      UpdateStackLimit();
      return kStackCheckDebugInterrupt;
    }
  }

  int size_increase = Utils::RoundUpToPowerOfTwo(addition);
  size_increase = Utils::Maximum(256, size_increase);
  int new_size = stack()->length() + size_increase;
  if (new_size > Platform::MaxStackSizeInWords()) return kStackCheckOverflow;

  Object* new_stack_object = NewStack(new_size);
  if (new_stack_object->IsRetryAfterGCFailure()) {
    program()->CollectNewSpace();
    new_stack_object = NewStack(new_size);
    if (new_stack_object->IsRetryAfterGCFailure()) {
      program()->CollectSharedGarbage();
      new_stack_object = NewStack(new_size);
      if (new_stack_object->IsRetryAfterGCFailure()) {
        return kStackCheckOverflow;
      }
    }
  }

  Stack* new_stack = Stack::cast(new_stack_object);
  word height = stack()->length() - stack()->top();
  ASSERT(height >= 0);
  new_stack->set_top(new_stack->length() - height);
  memcpy(new_stack->Pointer(new_stack->top()), stack()->Pointer(stack()->top()),
         height * kWordSize);
  new_stack->UpdateFramePointers(stack());
  ASSERT(coroutine_->has_stack());
  coroutine_->set_stack(new_stack);
  remembered_set_.Insert(coroutine_->stack());
  UpdateStackLimit();
  return kStackCheckContinue;
}

Object* Process::NewByteArray(int length) {
  RegisterProcessAllocation();
  Class* byte_array_class = program()->byte_array_class();
  return heap()->CreateByteArray(byte_array_class, length);
}

Object* Process::NewArray(int length) {
  RegisterProcessAllocation();
  Class* array_class = program()->array_class();
  Object* null = program()->null_object();
  Object* result = heap()->CreateArray(array_class, length, null);
  return result;
}

Object* Process::NewDouble(fletch_double value) {
  RegisterProcessAllocation();
  Class* double_class = program()->double_class();
  Object* result = heap()->CreateDouble(double_class, value);
  return result;
}

Object* Process::NewInteger(int64 value) {
  RegisterProcessAllocation();
  Class* large_integer_class = program()->large_integer_class();
  Object* result =
      heap()->CreateLargeInteger(large_integer_class, value);
  return result;
}

void Process::TryDeallocInteger(LargeInteger* object) {
  heap()->TryDeallocInteger(object);
}

Object* Process::NewOneByteString(int length) {
  RegisterProcessAllocation();
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result =
      heap()->CreateOneByteString(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return OneByteString::cast(raw_result);
}

Object* Process::NewTwoByteString(int length) {
  RegisterProcessAllocation();
  Class* string_class = program()->two_byte_string_class();
  Object* raw_result =
      heap()->CreateTwoByteString(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return TwoByteString::cast(raw_result);
}

Object* Process::NewOneByteStringUninitialized(int length) {
  RegisterProcessAllocation();
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result =
      heap()->CreateOneByteStringUninitialized(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return OneByteString::cast(raw_result);
}

Object* Process::NewTwoByteStringUninitialized(int length) {
  RegisterProcessAllocation();
  Class* string_class = program()->two_byte_string_class();
  Object* raw_result =
      heap()->CreateTwoByteStringUninitialized(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return TwoByteString::cast(raw_result);
}

Object* Process::NewStringFromAscii(List<const char> value) {
  RegisterProcessAllocation();
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result = heap()->CreateOneByteStringUninitialized(
      string_class, value.length());
  if (raw_result->IsFailure()) return raw_result;
  OneByteString* result = OneByteString::cast(raw_result);
  for (int i = 0; i < value.length(); i++) {
    result->set_char_code(i, value[i]);
  }
  return result;
}

Object* Process::NewBoxed(Object* value) {
  RegisterProcessAllocation();
  Class* boxed_class = program()->boxed_class();
  Object* result = heap()->CreateBoxed(boxed_class, value);
  if (result->IsFailure()) return result;
  return result;
}

Object* Process::NewInstance(Class* klass, bool immutable) {
  RegisterProcessAllocation();
  Object* null = program()->null_object();
  return heap()->CreateInstance(klass, null, immutable);
}

Object* Process::ToInteger(int64 value) {
  return Smi::IsValid(value) ? Smi::FromWord(value) : NewInteger(value);
}

Object* Process::NewStack(int length) {
  RegisterProcessAllocation();
  Class* stack_class = program()->stack_class();
  Object* result = heap()->CreateStack(stack_class, length);

  if (result->IsFailure()) return result;
  remembered_set_.Insert(HeapObject::cast(result));
  return result;
}

void Process::ValidateHeaps() {
  ProcessHeapValidatorVisitor v(program()->heap());
  v.VisitProcess(this);
}

void Process::IterateRoots(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&statics_));
  visitor->Visit(reinterpret_cast<Object**>(&coroutine_));
  visitor->Visit(reinterpret_cast<Object**>(&exception_));
  if (debug_info_ != NULL) debug_info_->VisitPointers(visitor);

  mailbox_.IteratePointers(visitor);
}

void Process::IterateProgramPointers(PointerVisitor* visitor) {
  // TODO(erikcorry): Somehow assert that the stacks are cooked (there's no
  // simple way to tell in a multiple-processes-per-heap world).
  if (debug_info_ != NULL) debug_info_->VisitProgramPointers(visitor);
  visitor->Visit(&exception_);
  mailbox_.IteratePointers(visitor);
}

void Process::TakeLookupCache() {
  ASSERT(primary_lookup_cache_ == NULL);
  if (program()->is_optimized()) return;
  LookupCache* cache = program()->EnsureCache();
  primary_lookup_cache_ = cache->primary();
}

void Process::SetStackMarker(uword marker) {
  uword stack_limit = stack_limit_;
  while (true) {
    uword updated_limit =
        stack_limit < kMaxStackMarker ? kMaxStackMarker : stack_limit;
    updated_limit |= marker;
    if (stack_limit_.compare_exchange_weak(stack_limit, updated_limit)) break;
  }
}

void Process::ClearStackMarker(uword marker) {
  uword stack_limit = stack_limit_;
  while (true) {
    ASSERT((stack_limit & marker) != 0);
    uword updated_limit = stack_limit & (~marker);
    if (stack_limit_.compare_exchange_weak(stack_limit, updated_limit)) break;
  }
}

void Process::Preempt() { SetStackMarker(kPreemptMarker); }

void Process::DebugInterrupt() { SetStackMarker(kDebugInterruptMarker); }

void Process::EnsureDebuggerAttached(Session* session) {
  if (debug_info_ == NULL) {
    debug_info_ = new DebugInfo(session->FreshProcessId());
  }
}

int Process::PrepareStepOver() {
  ASSERT(debug_info_ != NULL);
  Frame frame(stack());
  frame.MovePrevious();

  uint8_t* current_bcp = frame.ByteCodePointer();
  Opcode opcode = static_cast<Opcode>(*current_bcp);
  if (!Bytecode::IsInvokeVariant(opcode)) {
    // For non-invoke bytecodes step over is the same as step.
    debug_info_->SetStepping();
    return DebugInfo::kNoBreakpointId;
  }

  // TODO(ager): We should consider making this less bytecode-specific.
  int stack_diff = 0;
  switch (opcode) {
    // For invoke bytecodes we set a one-shot breakpoint for the next bytecode
    // with the expected stack height on return.
    case Opcode::kInvokeMethodUnfold:
    case Opcode::kInvokeNoSuchMethod:
    case Opcode::kInvokeMethod: {
      int selector = Utils::ReadInt32(current_bcp + 1);
      int arity = Selector::ArityField::decode(selector);
      stack_diff = -arity;
      break;
    }
    case Opcode::kInvokeStatic:
    case Opcode::kInvokeFactory: {
      Function* function =
          Function::cast(Function::ConstantForBytecode(current_bcp));
      stack_diff = 1 - function->arity();
      break;
    }
    default:
      stack_diff = Bytecode::StackDiff(opcode);
      break;
  }

  Function* function = Function::FromBytecodePointer(current_bcp);
  word frame_end = stack()->top() - stack_diff + 2;
  word stack_height = stack()->length() - frame_end;
  int bytecode_index =
      current_bcp + Bytecode::Size(opcode) - function->bytecode_address_for(0);
  return debug_info_->SetBreakpoint(function, bytecode_index, true, coroutine_,
                                    stack_height);
}

int Process::PrepareStepOut() {
  ASSERT(debug_info_ != NULL);
  Frame frame(stack());
  bool has_top_frame = frame.MovePrevious();
  ASSERT(has_top_frame);
  Object** frame_bottom = frame.FramePointer() + 1;
  Function* callee = frame.FunctionFromByteCodePointer();
  bool has_frame_below = frame.MovePrevious();
  ASSERT(has_frame_below);
  Function* caller = frame.FunctionFromByteCodePointer();
  uint8* bcp = frame.ByteCodePointer();
  bcp += Bytecode::Size(static_cast<Opcode>(*bcp));
  int bytecode_index = bcp - caller->bytecode_address_for(0);
  Object** expected_sp = frame_bottom + callee->arity();
  word frame_end = expected_sp - stack()->Pointer(0);
  word stack_height = stack()->length() - frame_end;
  return debug_info_->SetBreakpoint(caller, bytecode_index, true, coroutine_,
                                    stack_height);
}

void Process::UpdateBreakpoints() {
  if (debug_info_ != NULL) {
    debug_info_->UpdateBreakpoints();
  }
}

void Process::RegisterFinalizer(HeapObject* object,
                                WeakPointerCallback callback) {
  uword address = object->address();
  ASSERT(heap()->space()->Includes(address));
  heap()->AddWeakPointer(object, callback);
}

void Process::UnregisterFinalizer(HeapObject* object) {
  uword address = object->address();
  // We do not support unregistering weak pointers for the immutable heap (and
  // it is currently also not used for immutable objects).
  ASSERT(heap()->space()->Includes(address));
  heap()->RemoveWeakPointer(object);
}

void Process::FinalizeForeign(HeapObject* foreign, Heap* heap) {
  Instance* instance = Instance::cast(foreign);
  uword value = instance->GetConsecutiveSmis(0);
  uword length = Smi::cast(instance->GetInstanceField(2))->value();
  free(reinterpret_cast<void*>(value));
  heap->FreedForeignMemory(length);
}

void Process::FinalizeProcess(HeapObject* process, Heap* heap) {
  ProcessHandle* handle = ProcessHandle::FromDartObject(process);
  ProcessHandle::DecrementRef(handle);
}

#ifdef DEBUG
bool Process::TrueThenFalse() {
  bool result = true_then_false_;
  true_then_false_ = !true_then_false_;
  return result;
}
#endif

void Process::StoreErrno() { errno_cache_ = Platform::GetLastError(); }

void Process::RestoreErrno() { Platform::SetLastError(errno_cache_); }

void Process::SendSignal(Signal* signal) {
  while (signal_.load() == NULL) {
    Signal* expected = NULL;
    if (signal_.compare_exchange_weak(expected, signal)) {
      return;
    }
  }
  Signal::DecrementRef(signal);
}

void Process::UpdateStackLimit() {
  // By adding 2, we reserve a slot for a return address and an extra
  // temporary each bytecode can utilize internally.
  Stack* stack = this->stack();
  int frame_size = Bytecode::kGuaranteedFrameSize + 2;
  uword current_limit = stack_limit_;
  // Update the stack limit if the limit is a real limit or if all
  // interrupts have been handled.
  if (current_limit <= kMaxStackMarker) {
    uword new_stack_limit = reinterpret_cast<uword>(stack->Pointer(frame_size));
    stack_limit_.compare_exchange_strong(current_limit, new_stack_limit);
  }
}

LookupCache::Entry* Process::LookupEntrySlow(LookupCache::Entry* primary,
                                             Class* clazz, int selector) {
  ASSERT(!program()->is_optimized());
  LookupCache* cache = program()->cache();

  uword index = LookupCache::ComputeSecondaryIndex(clazz, selector);
  LookupCache::Entry* secondary = &(cache->secondary()[index]);
  if (secondary->clazz == clazz && secondary->selector == selector) {
    return secondary;
  }

  void* code = NULL;
  Function* target = clazz->LookupMethod(selector);
  if (target == NULL) {
    static const Names::Id name = Names::kNoSuchMethodTrampoline;
    target = clazz->LookupMethod(Selector::Encode(name, Selector::METHOD, 0));
  } else {
    IntrinsicsTable* intrinsics = IntrinsicsTable::GetDefault();
    Intrinsic intrinsic = target->ComputeIntrinsic(intrinsics);
    code = intrinsics->GetCode(intrinsic);
    if (code == NULL) code = reinterpret_cast<void*>(InterpreterMethodEntry);
  }

  ASSERT(target != NULL);
  cache->DemotePrimary(primary);
  primary->clazz = clazz;
  primary->selector = selector;
  primary->target = target;
  primary->code = code;
  return primary;
}

BEGIN_NATIVE(ProcessQueueGetMessage) {
  MessageMailbox* mailbox = process->mailbox();

  Message* queue = mailbox->CurrentMessage();
  Message::Kind kind = queue->kind();
  Object* result = Smi::FromWord(0);

  switch (kind) {
    case Message::IMMEDIATE:
    case Message::IMMUTABLE_OBJECT:
      result = reinterpret_cast<Object*>(queue->value());
      break;

    case Message::FOREIGN:
    case Message::FOREIGN_FINALIZED: {
      Class* foreign_memory_class = process->program()->foreign_memory_class();
      ASSERT(foreign_memory_class->NumberOfInstanceFields() == 4);
      Object* object = process->NewInstance(foreign_memory_class);
      if (object->IsRetryAfterGCFailure()) return object;
      Instance* foreign = Instance::cast(object);
      foreign->SetConsecutiveSmis(0, queue->value());
      int size = queue->size();
      foreign->SetInstanceField(2, Smi::FromWord(size));
      if (kind == Message::FOREIGN_FINALIZED) {
        process->RegisterFinalizer(foreign, Process::FinalizeForeign);
        process->heap()->AllocatedForeignMemory(size);
      }
      result = foreign;
      break;
    }

    case Message::LARGE_INTEGER: {
      result = process->NewInteger(queue->value());
      if (result->IsRetryAfterGCFailure()) return result;
      break;
    }

    case Message::EXIT: {
      result = queue->ExitReferenceObject();
      break;
    }

    case Message::PROCESS_DEATH_SIGNAL: {
      // Process death signal creation is a two-step process. The
      // first step creates the process death object and does not
      // advance the message queue. The second step initializes the
      // process death object by calling ProcessQueueSetupProcessDeath
      // which advances the message queue. This is to get around the
      // restriction that natives can only perform one allocation.
      Program* program = process->program();
      Signal* signal = queue->ProcessDeathSignal();
      Object* process_death =
          process->NewInstance(program->process_death_class(), true);
      if (process_death->IsRetryAfterGCFailure()) return process_death;
      Instance::cast(process_death)
          ->SetInstanceField(1, Smi::FromWord(signal->kind()));
      // Return without advancing the message queue.
      return process_death;
    }

    default:
      UNREACHABLE();
  }

  mailbox->AdvanceCurrentMessage();
  return result;
}
END_NATIVE()

BEGIN_NATIVE(ProcessQueueSetupProcessDeath) {
  MessageMailbox* mailbox = process->mailbox();
  Message* queue = mailbox->CurrentMessage();
  Message::Kind kind = queue->kind();

  if (kind != Message::PROCESS_DEATH_SIGNAL) {
    FATAL("Process death message creation failed.\n");
  }

  Program* program = process->program();
  Object* dart_process = process->NewInstance(program->process_class(), true);
  if (dart_process->IsRetryAfterGCFailure()) return dart_process;

  Signal* signal = queue->ProcessDeathSignal();
  ProcessHandle* handle = signal->handle();
  handle->IncrementRef();
  handle->InitializeDartObject(dart_process);
  Instance::cast(arguments[0])->SetInstanceField(0, dart_process);

  process->RegisterFinalizer(HeapObject::cast(dart_process),
                             Process::FinalizeProcess);

  mailbox->AdvanceCurrentMessage();
  return arguments[0];
}
END_NATIVE()

BEGIN_NATIVE(ProcessQueueGetChannel) {
  MessageMailbox* mailbox = process->mailbox();

  Message* queue = mailbox->CurrentMessage();
  // The channel for a port can die independently of the port. In that case
  // messages sent to the port can never be received. In that case we drop the
  // message when processing the message queue.
  while (queue != NULL) {
    Instance* channel = queue->port()->channel();
    if (channel != NULL) return channel;
    mailbox->AdvanceCurrentMessage();
    queue = mailbox->CurrentMessage();
  }
  return process->program()->null_object();
}
END_NATIVE()

}  // namespace fletch
