// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/process.h"

#include <errno.h>
#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/heap_validator.h"
#include "src/vm/natives.h"
#include "src/vm/object_memory.h"
#include "src/vm/port.h"
#include "src/vm/process_queue.h"
#include "src/vm/session.h"
#include "src/vm/stack_walker.h"

namespace fletch {

static Object** kPreemptMarker = reinterpret_cast<Object**>(1);
static Object** kProfileMarker = reinterpret_cast<Object**>(2);

class ExitReference {
 public:
  ExitReference(Process* exiting_process, Object* message)
      : mutable_heap_(NULL, reinterpret_cast<WeakPointer*>(NULL)),
        store_buffer_(true),
        message_(message) {
    mutable_heap_.MergeInOtherHeap(exiting_process->heap());
    store_buffer_.Prepend(exiting_process->store_buffer());
  }

  Object* message() const { return message_; }

  void VisitPointers(PointerVisitor* visitor) {
    visitor->Visit(&message_);
  }

  Heap* mutable_heap() { return &mutable_heap_; }

  StoreBuffer* store_buffer() { return &store_buffer_; }

 private:
  Heap mutable_heap_;
  StoreBuffer store_buffer_;
  Object* message_;
};

class PortQueue {
 public:
  enum Kind {
    IMMEDIATE,
    OBJECT,
    FOREIGN,
    FOREIGN_FINALIZED,
    EXIT
  };

  PortQueue(Port* port, uword value, int size, Kind kind)
      : port_(port),
        value_(value),
        next_(NULL),
        kind_and_size_(KindField::encode(kind) | SizeField::encode(size)) {
    port_->IncrementRef();
  }

  ~PortQueue() {
    port_->DecrementRef();
    if (kind() == EXIT) {
      ExitReference* ref = reinterpret_cast<ExitReference*>(address());
      delete ref;
    }
  }

  Port* port() const { return port_; }
  uword address() const { return value_; }
  int size() const { return SizeField::decode(kind_and_size_); }
  Kind kind() const { return KindField::decode(kind_and_size_); }

  PortQueue* next() const { return next_; }
  void set_next(PortQueue* next) { next_ = next; }

  void VisitPointers(PointerVisitor* visitor) {
    switch (kind()) {
      case OBJECT:
        visitor->Visit(reinterpret_cast<Object**>(&value_));
        break;
      case EXIT: {
        ExitReference* ref = reinterpret_cast<ExitReference*>(address());
        ref->VisitPointers(visitor);
        break;
      }
      default:
        break;
    }
  }

 private:
  Port* port_;
  uword value_;
  PortQueue* next_;
  class KindField: public BitField<Kind, 0, 3> { };
  class SizeField: public BitField<int, 3, 32 - 3> { };
  const int32 kind_and_size_;
};

ThreadState::ThreadState()
    : thread_id_(-1),
      queue_(new ProcessQueue()),
      cache_(NULL),
      idle_monitor_(Platform::CreateMonitor()),
      next_idle_thread_(NULL) {
}

void ThreadState::AttachToCurrentThread() {
  thread_ = ThreadIdentifier();
}

LookupCache* ThreadState::EnsureCache() {
  if (cache_ == NULL) cache_ = new LookupCache();
  return cache_;
}

ThreadState::~ThreadState() {
  delete idle_monitor_;
  delete queue_;
  delete cache_;
}

Process::Process(Program* program)
    : coroutine_(NULL),
      stack_limit_(NULL),
      program_(program),
      statics_(NULL),
      primary_lookup_cache_(NULL),
      random_(program->random()->NextUInt32() + 1),
      heap_(&random_, 4 * KB),
      immutable_heap_(NULL),
      state_(kSleeping),
      thread_state_(NULL),
      next_(NULL),
      queue_(NULL),
      queue_next_(NULL),
      queue_previous_(NULL),
      ports_(NULL),
      last_message_(NULL),
      current_message_(NULL),
      process_list_next_(NULL),
      process_list_prev_(NULL),
      errno_cache_(0),
      debug_info_(NULL) {
  // These asserts need to hold when running on the target, but they don't need
  // to hold on the host (the build machine, where the interpreter-generating
  // program runs).  We put these asserts here on the assumption that the
  // interpreter-generating program will not instantiate this class.
  static_assert(kCoroutineOffset == offsetof(Process, coroutine_),
      "coroutine_");
  static_assert(kStackLimitOffset == offsetof(Process, stack_limit_),
      "stack_limit_");
  static_assert(kProgramOffset == offsetof(Process, program_), "program_");
  static_assert(kStaticsOffset == offsetof(Process, statics_), "statics_");
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
  delete debug_info_;

  ASSERT(next_ == NULL);
  ASSERT(cooked_stack_deltas_.is_empty());
  // Clear out the process pointer from all the ports.
  heap_.ProcessWeakPointers();
  ASSERT(immutable_heap_ == NULL);
  while (ports_ != NULL) {
    Port* next = ports_->next();
    ports_->OwnerProcessTerminating();
    ports_ = next;
  }
  while (last_message_ != NULL) {
    PortQueue* entry = last_message_;
    last_message_ = entry->next();
    delete entry;
  }
  ASSERT(last_message_ == NULL);
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
  store_buffer_.Insert(coroutine->stack());
}

Process::StackCheckResult Process::HandleStackOverflow(int addition) {
  Object** current_limit = stack_limit();

  if (current_limit == kProfileMarker) {
    stack_limit_ = NULL;
    UpdateStackLimit();
    return kStackCheckContinue;
  }

  // When the stack_limit is kPreemptMarker, the process has been explicitly
  // asked to preempt.
  if (current_limit == kPreemptMarker) {
    stack_limit_ = NULL;
    UpdateStackLimit();
    return kStackCheckInterrupt;
  }

  int size_increase = Utils::RoundUpToPowerOfTwo(addition);
  size_increase = Utils::Maximum(256, size_increase);
  int new_size = stack()->length() + size_increase;
  if (new_size > 128 * KB) return kStackCheckOverflow;

  Object* new_stack_object = NewStack(new_size);
  if (new_stack_object == Failure::retry_after_gc()) {
    CollectMutableGarbage();
    new_stack_object = NewStack(new_size);
    if (new_stack_object->IsFailure()) {
      FATAL("Failed to increase stack size");
    }
  }

  Stack* new_stack = Stack::cast(new_stack_object);
  int top = stack()->top();
  new_stack->set_top(top);
  for (int i = 0; i <= top; i++) {
    new_stack->set(i, stack()->get(i));
  }
  ASSERT(coroutine_->has_stack());
  coroutine_->set_stack(new_stack);
  store_buffer_.Insert(coroutine_->stack());
  UpdateStackLimit();
  return kStackCheckContinue;
}

Object* Process::NewByteArray(int length) {
  Class* byte_array_class = program()->byte_array_class();
  return heap_.CreateByteArray(byte_array_class, length);
}

Object* Process::NewArray(int length) {
  Class* array_class = program()->array_class();
  Object* null = program()->null_object();
  Object* result = heap_.CreateArray(array_class, length, null);
  return result;
}

Object* Process::NewDouble(fletch_double value) {
  Class* double_class = program()->double_class();
  Object* result = immutable_heap_->CreateDouble(double_class, value);
  return result;
}

Object* Process::NewInteger(int64 value) {
  Class* large_integer_class = program()->large_integer_class();
  Object* result = immutable_heap_->CreateLargeInteger(
      large_integer_class, value);
  return result;
}

void Process::TryDeallocInteger(LargeInteger* object) {
  immutable_heap_->TryDeallocInteger(object);
}

Object* Process::NewOneByteString(int length) {
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result = immutable_heap_->CreateOneByteString(
      string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return OneByteString::cast(raw_result);
}

Object* Process::NewTwoByteString(int length) {
  Class* string_class = program()->two_byte_string_class();
  Object* raw_result = immutable_heap_->CreateTwoByteString(
      string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return TwoByteString::cast(raw_result);
}

Object* Process::NewOneByteStringUninitialized(int length) {
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result = immutable_heap_->CreateOneByteStringUninitialized(
      string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return OneByteString::cast(raw_result);
}

Object* Process::NewTwoByteStringUninitialized(int length) {
  Class* string_class = program()->two_byte_string_class();
  Object* raw_result = immutable_heap_->CreateTwoByteStringUninitialized(
      string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return TwoByteString::cast(raw_result);
}

Object* Process::NewStringFromAscii(List<const char> value) {
  Class* string_class = program()->one_byte_string_class();
  Object* raw_result = immutable_heap_->CreateOneByteStringUninitialized(
      string_class, value.length());
  if (raw_result->IsFailure()) return raw_result;
  OneByteString* result = OneByteString::cast(raw_result);
  for (int i = 0; i < value.length(); i++) {
    result->set_char_code(i, value[i]);
  }
  return result;
}

Object* Process::NewBoxed(Object* value) {
  Class* boxed_class = program()->boxed_class();
  Object* result = heap_.CreateBoxed(boxed_class, value);
  if (result->IsFailure()) return result;
  return result;
}

Object* Process::NewInstance(Class* klass, bool immutable) {
  Object* null = program()->null_object();
  if (immutable) {
    return immutable_heap_->CreateInstance(klass, null, immutable);
  } else {
    return heap_.CreateInstance(klass, null, immutable);
  }
}

Object* Process::ToInteger(int64 value) {
  return Smi::IsValid(value)
      ? Smi::FromWord(value)
      : NewInteger(value);
}

Object* Process::NewStack(int length) {
  Class* stack_class = program()->stack_class();
  Object* result = heap_.CreateStack(stack_class, length);

  if (result->IsFailure()) return result;
  store_buffer_.Insert(HeapObject::cast(result));
  return result;
}

struct HeapUsage {
  uint64 timestamp = 0;
  uword process_used = 0;
  uword process_size = 0;
  uword immutable_used = 0;
  uword immutable_size = 0;
  uword program_used = 0;
  uword program_size = 0;

  uword TotalUsed() { return process_used + immutable_used + program_used; }
  uword TotalSize() { return process_used + immutable_size + program_size; }
};

static void GetHeapUsage(Process* process, HeapUsage* heap_usage) {
  heap_usage->timestamp = Platform::GetMicroseconds();
  heap_usage->process_used = process->heap()->space()->Used();
  heap_usage->process_size = process->heap()->space()->Size();
  heap_usage->immutable_used =
      process->program()->immutable_heap()->EstimatedUsed();
  heap_usage->immutable_size =
      process->program()->immutable_heap()->EstimatedSize();
  heap_usage->program_used = process->program()->heap()->space()->Used();
  heap_usage->program_size = process->program()->heap()->space()->Size();
}

void PrintProcessGCInfo(Process* process, HeapUsage* before, HeapUsage* after) {
  static int count = 0;
  if ((count & 0xF) == 0) {
    Print::Error(
        "Program-GC-Info, \tElapsed, \tProcess use/size, \tImmutable use/size,"
        " \tProgram use/size, \tTotal heap\n");
  }
  Print::Error(
      "Process-GC(%i, %p): "
      "\t%lli us, "
      "\t%lu/%lu -> %lu/%lu, "
      "\t%lu/%lu, "
      "\t%lu/%lu, "
      "\t%lu/%lu -> %lu/%lu\n",
      count++,
      process,
      after->timestamp - before->timestamp,
      before->process_used,
      before->process_size,
      after->process_used,
      after->process_size,
      after->immutable_used,
      after->immutable_size,
      after->program_used,
      after->program_size,
      before->TotalUsed(),
      before->TotalSize(),
      after->TotalUsed(),
      after->TotalSize());
}

void Process::CollectMutableGarbage() {
  TakeChildHeaps();

  HeapUsage usage_before;
  if (Flags::print_heap_statistics) {
    GetHeapUsage(this, &usage_before);
  }

  Space* from = heap_.space();
  Space* to = new Space(from->Used() / 10);
  StoreBuffer sb;

  // While garbage collecting, do not fail allocations. Instead grow
  // the to-space as needed.
  NoAllocationFailureScope scope(to);

  ScavengeVisitor visitor(from, to);
  IterateRoots(&visitor);

  ASSERT(!to->is_empty());
  Space* program_space = program()->heap()->space();
  to->CompleteScavengeMutable(&visitor, program_space, &sb);
  store_buffer_.ReplaceAfterMutableGC(&sb);

  heap_.ProcessWeakPointers();
  set_ports(Port::CleanupPorts(from, ports()));
  heap_.ReplaceSpace(to);
  UpdateStackLimit();

  if (Flags::print_heap_statistics) {
    HeapUsage usage_after;
    GetHeapUsage(this, &usage_after);
    PrintProcessGCInfo(this, &usage_before, &usage_after);
  }
}

// Helper class for copying HeapObjects and chaining stacks for a
// process..
class ScavengeAndChainStacksVisitor: public PointerVisitor {
 public:
  ScavengeAndChainStacksVisitor(Process* process,
                                Space* from,
                                Space* to)
      : process_(process),
        from_(from),
        to_(to),
        number_of_stacks_(0) { }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) ScavengePointerAndChainStack(p);
  }

  int number_of_stacks() const { return number_of_stacks_; }

 private:
  void ChainStack(Stack* stack) {
    number_of_stacks_++;
    Stack* process_stack = process_->stack();
    if (process_stack != stack) {
      // We rely on the fact that the current coroutine stack is
      // visited first.
      ASSERT(to_->Includes(reinterpret_cast<uword>(process_stack)));
      stack->set_next(process_stack->next());
      process_stack->set_next(stack);
    }
  }

  void ScavengePointerAndChainStack(Object** p) {
    Object* object = *p;
    if (!object->IsHeapObject()) return;
    if (!from_->Includes(reinterpret_cast<uword>(object))) return;
    bool forwarded = HeapObject::cast(object)->forwarding_address() != NULL;
    *p = reinterpret_cast<HeapObject*>(object)->CloneInToSpace(to_);
    if (!forwarded) {
      if ((*p)->IsStack()) {
        ChainStack(Stack::cast(*p));
      }
    }
  }

  Process* process_;
  Space* from_;
  Space* to_;
  int number_of_stacks_;
};

int Process::CollectMutableGarbageAndChainStacks() {
  Space* from = heap_.space();
  Space* to = new Space(from->Used() / 10);
  StoreBuffer sb;

  // While garbage collecting, do not fail allocations. Instead grow
  // the to-space as needed.
  NoAllocationFailureScope scope(to);
  ScavengeAndChainStacksVisitor visitor(this, from, to);

  // Visit the current coroutine stack first and chain the rest of the
  // stacks starting from there.
  visitor.Visit(reinterpret_cast<Object**>(coroutine_->stack_address()));
  IterateRoots(&visitor);
  Space* program_space = program()->heap()->space();
  to->CompleteScavengeMutable(&visitor, program_space, &sb);
  store_buffer_.ReplaceAfterMutableGC(&sb);

  heap_.ProcessWeakPointers();
  set_ports(Port::CleanupPorts(from, ports()));
  heap_.ReplaceSpace(to);
  UpdateStackLimit();
  return visitor.number_of_stacks();
}

int Process::CollectGarbageAndChainStacks() {
  // NOTE: We need to take all spaces which are getting merged into our
  // heap, because otherwise we'll not update the pointers it has to the
  // program space / to the process heap.
  TakeChildHeaps();

  int number_of_stacks = CollectMutableGarbageAndChainStacks();
  return number_of_stacks;
}

void Process::ValidateHeaps(ImmutableHeap* immutable_heap) {
  ProcessHeapValidatorVisitor v(program()->heap(), immutable_heap);
  v.VisitProcess(this);
}

static void IteratePortQueuePointers(PortQueue* queue,
                                     PointerVisitor* visitor) {
  for (PortQueue* current = queue;
       current != NULL;
       current = current->next()) {
     current->VisitPointers(visitor);
  }
}

void Process::IterateRoots(PointerVisitor* visitor) {
  visitor->Visit(reinterpret_cast<Object**>(&statics_));
  visitor->Visit(reinterpret_cast<Object**>(&coroutine_));
  if (debug_info_ != NULL) debug_info_->VisitPointers(visitor);
  IteratePortQueuesPointers(visitor);
}

void Process::IterateProgramPointers(PointerVisitor* visitor) {
  ASSERT(stacks_are_cooked());
  HeapObjectPointerVisitor program_pointer_visitor(visitor);
  heap()->IterateObjects(&program_pointer_visitor);
  store_buffer_.IteratePointersToImmutableSpace(visitor);
  if (debug_info_ != NULL) debug_info_->VisitProgramPointers(visitor);
  IteratePortQueuesPointers(visitor);
}

void Process::IteratePortQueuesPointers(PointerVisitor* visitor) {
  IteratePortQueuePointers(last_message_, visitor);
  IteratePortQueuePointers(current_message_, visitor);
}

void Process::TakeLookupCache() {
  ASSERT(primary_lookup_cache_ == NULL);
  if (program()->is_compact()) return;
  ThreadState* state = thread_state_;
  ASSERT(state != NULL);
  LookupCache* cache = state->EnsureCache();
  primary_lookup_cache_ = cache->primary();
}

void Process::Preempt() {
  stack_limit_ = kPreemptMarker;
}

void Process::Profile() {
  // Don't override preempt marker.
  Object** stack_limit = stack_limit_;
  if (stack_limit_ == kPreemptMarker) return;
  stack_limit_.compare_exchange_strong(stack_limit, kProfileMarker);
}

void Process::AttachDebugger() {
  ASSERT(debug_info_ == NULL);
  debug_info_ = new DebugInfo();
}

int Process::PrepareStepOver() {
  Object** pushed_bcp_address = stack()->Pointer(stack()->top());
  uint8_t* current_bcp = reinterpret_cast<uint8_t*>(*pushed_bcp_address);
  Object** stack_top = pushed_bcp_address - 1;
  Opcode opcode = static_cast<Opcode>(*current_bcp);

  if (!Bytecode::IsInvoke(opcode)) {
    // For non-invoke bytecodes step over is the same as step.
    debug_info_->set_is_stepping(true);
    return DebugInfo::kNoBreakpointId;
  }

  // TODO(ager): We should share this code with the stack walker that also
  // needs to know the stack diff for each bytecode.
  int stack_diff = 0;
  switch (opcode) {
    // For invoke bytecodes we set a one-shot breakpoint for the next bytecode
    // with the expected stack height on return.
    case Opcode::kInvokeMethod:
    case Opcode::kInvokeMethodVtable: {
      int selector = Utils::ReadInt32(current_bcp + 1);
      int arity = Selector::ArityField::decode(selector);
      stack_diff = -arity;
      break;
    }
    case Opcode::kInvokeMethodFast: {
      int index = Utils::ReadInt32(current_bcp + 1);
      Array* table = program()->dispatch_table();
      int selector = Smi::cast(table->get(index + 1))->value();
      int arity = Selector::ArityField::decode(selector);
      stack_diff = -arity;
      break;
    }
    case Opcode::kInvokeStatic:
    case Opcode::kInvokeFactory: {
      int method = Utils::ReadInt32(current_bcp + 1);
      Function* function = program()->static_method_at(method);
      stack_diff = 1 - function->arity();
      break;
    }
    case Opcode::kInvokeStaticUnfold:
    case Opcode::kInvokeFactoryUnfold: {
      Function* function =
          Function::cast(Function::ConstantForBytecode(current_bcp));
      stack_diff = 1 - function->arity();
      break;
    }
    default:
      stack_diff = Bytecode::StackDiff(opcode);
      break;
  }

  Object** expected_sp = stack_top + stack_diff;
  Function* function = Function::FromBytecodePointer(current_bcp);
  int stack_height = expected_sp - stack()->Pointer(0);
  int bytecode_index =
      current_bcp + Bytecode::Size(opcode) - function->bytecode_address_for(0);
  return debug_info_->SetBreakpoint(
    function, bytecode_index, true, coroutine_, stack_height);
}

int Process::PrepareStepOut() {
  StackWalker stack_walker(this, stack());
  bool has_top_frame = stack_walker.MoveNext();
  ASSERT(has_top_frame);
  int top_frame_size = -stack_walker.stack_offset();
  Function* callee = stack_walker.function();
  bool has_frame_below = stack_walker.MoveNext();
  ASSERT(has_frame_below);
  Function* caller = stack_walker.function();
  int bytecode_index =
      stack_walker.return_address() - caller->bytecode_address_for(0);
  Object** stack_top = stack()->Pointer(stack()->top());
  Object** expected_sp = stack_top - top_frame_size - callee->arity();
  int stack_height = expected_sp - stack()->Pointer(0);
  return debug_info_->SetBreakpoint(
      caller, bytecode_index, true, coroutine_, stack_height);
}

void Process::CookStacks(int number_of_stacks) {
  cooked_stack_deltas_ = List<List<int>>::New(number_of_stacks);
  Object* raw_current = stack();
  for (int i = 0; i < number_of_stacks; ++i) {
    // TODO(ager): Space/time trade-off. Should we iterate the stack first
    // to count the number of frames to reduce memory pressure?
    Stack* current = Stack::cast(raw_current);
    cooked_stack_deltas_[i] = List<int>::New(stack()->length());
    int index = 0;
    StackWalker stack_walker(this, current);
    while (stack_walker.MoveNext()) {
      cooked_stack_deltas_[i][index++] = stack_walker.CookFrame();
    }
    raw_current = current->next();
  }
  ASSERT(raw_current == Smi::zero());
}

void Process::UncookAndUnchainStacks() {
  Object* raw_current = stack();
  for (int i = 0; i < cooked_stack_deltas_.length(); ++i) {
    Stack* current = Stack::cast(raw_current);
    StackWalker stack_walker(this, current);
    int index = 0;
    do {
      stack_walker.UncookFrame(cooked_stack_deltas_[i][index++]);
    } while (stack_walker.MoveNext());
    cooked_stack_deltas_[i].Delete();
    raw_current = current->next();
    current->set_next(Smi::FromWord(0));
  }
  ASSERT(raw_current == Smi::zero());
  cooked_stack_deltas_.Delete();
}

void Process::UpdateBreakpoints() {
  if (debug_info_ != NULL) {
    debug_info_->UpdateBreakpoints();
  }
}

bool Process::Enqueue(Port* port, Object* message) {
  PortQueue* entry = NULL;
  if (!message->IsHeapObject()) {
    uword address = reinterpret_cast<uword>(message);
    entry = new PortQueue(port, address, 0, PortQueue::IMMEDIATE);
  } else if (message->IsImmutable()) {
    uword address = reinterpret_cast<uword>(message);
    entry = new PortQueue(port, address, 0, PortQueue::OBJECT);
  } else {
    Space* space = program_->heap()->space();
    if (!space->Includes(HeapObject::cast(message)->address())) return false;

    // NOTE: The only case when we go into this else block is if [message] is
    // mutable. The objects in program space should all be immutable, so
    // [message] must be a mutable process heap message, in which case we
    // return `false` and the caller can use [Process::EnqueueExit].
    //
    // Any other scenario must be a bug and will hit this UNREACHABLE().
    UNREACHABLE();
  }

  EnqueueEntry(entry);
  return true;
}

bool Process::EnqueueForeign(Port* port,
                             void* foreign,
                             int size,
                             bool finalized) {
  PortQueue::Kind kind = finalized
      ? PortQueue::FOREIGN_FINALIZED
      : PortQueue::FOREIGN;
  uword address = reinterpret_cast<uword>(foreign);
  PortQueue* entry = new PortQueue(port, address, size, kind);
  EnqueueEntry(entry);
  return true;
}

void Process::EnqueueExit(Process* sender, Port* port, Object* message) {
  // TODO(kasperl): Optimize this to avoid merging heaps if copying is cheaper.
  uword address = reinterpret_cast<uword>(new ExitReference(sender, message));
  PortQueue* entry = new PortQueue(port, address, 0, PortQueue::EXIT);
  EnqueueEntry(entry);
}

bool Process::IsValidForEnqueue(Object* message) {
  Space* space = program_->heap()->space();
  return !message->IsHeapObject()
      || message->IsPort()
      || message->IsLargeInteger()
      || space->Includes(HeapObject::cast(message)->address());
}

static PortQueue* Reverse(PortQueue* queue) {
  PortQueue* previous = NULL;
  while (queue != NULL) {
    PortQueue* next = queue->next();
    queue->set_next(previous);
    previous = queue;
    queue = next;
  }
  return previous;
}

void Process::TakeQueue() {
  // Take the current queue.
  ASSERT(Thread::IsCurrent(thread_state_.load()->thread()));
  ASSERT(current_message_ == NULL);
  PortQueue* last = last_message_;
  while (!last_message_.compare_exchange_weak(last, NULL)) { }
  current_message_ = Reverse(last);
}

void Process::RegisterFinalizer(HeapObject* object,
                                WeakPointerCallback callback) {
  uword address = object->address();
  if (heap()->space()->Includes(address)) {
    heap()->AddWeakPointer(object, callback);
  } else {
    ASSERT(immutable_heap()->space()->Includes(address));
    immutable_heap()->AddWeakPointer(object, callback);
  }
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
  word value = AsForeignWord(instance->GetInstanceField(0));
  word length = AsForeignWord(instance->GetInstanceField(1));
  free(reinterpret_cast<void*>(value));
  heap->FreedForeignMemory(length);
}

#ifdef DEBUG
bool Process::TrueThenFalse() {
  bool result = true_then_false_;
  true_then_false_ = !true_then_false_;
  return result;
}
#endif

void Process::StoreErrno() {
  errno_cache_ = errno;
}

void Process::RestoreErrno() {
  errno = errno_cache_;
}

void Process::AdvanceCurrentMessage() {
  ASSERT(Thread::IsCurrent(thread_state_.load()->thread()));
  ASSERT(current_message_ != NULL);
  PortQueue* temp = current_message_;
  current_message_ = current_message_->next();
  delete temp;
}

// It's safe to call this method several times for the same ExitReference (e.g.
// during GC and when processing the message in it). If the spaces were already
// taken, this will be a NOP.
static void TakeExitReferenceHeaps(ExitReference* ref,
                                   Process* destination_process) {
  destination_process->heap()->MergeInOtherHeap(ref->mutable_heap());
  destination_process->store_buffer()->Prepend(ref->store_buffer());
}

static void TakePortQueueHeaps(PortQueue* queue, Process* destination_process) {
  for (PortQueue* current = queue;
       current != NULL;
       current = current->next()) {
    if (current->kind() == PortQueue::EXIT) {
      ExitReference* ref = reinterpret_cast<ExitReference*>(current->address());
      TakeExitReferenceHeaps(ref, destination_process);
    }
  }
}

void Process::TakeChildHeaps() {
  TakePortQueueHeaps(current_message_, this);
  TakePortQueueHeaps(last_message_, this);
}

PortQueue* Process::CurrentMessage() {
  ASSERT(Thread::IsCurrent(thread_state_.load()->thread()));
  if (current_message_ == NULL) TakeQueue();
  return current_message_;
}

void Process::UpdateStackLimit() {
  // By adding 2, we reserve a slot for a return address and an extra
  // temporary each bytecode can utilize internally.
  Stack* stack = this->stack();
  int frame_size = Bytecode::kGuaranteedFrameSize + 2;
  Object** current_limit = stack_limit_.load();
  if (current_limit != kPreemptMarker) {
    Object** new_stack_limit = stack->Pointer(stack->length() - frame_size);
    stack_limit_.compare_exchange_strong(current_limit, new_stack_limit);
  }
}

void Process::EnqueueEntry(PortQueue* entry) {
  ASSERT(entry->next() == NULL);
  PortQueue* last = last_message_;
  while (true) {
    entry->set_next(last);
    if (last_message_.compare_exchange_weak(last, entry)) break;
  }
}

LookupCache::Entry* Process::LookupEntrySlow(LookupCache::Entry* primary,
                                             Class* clazz,
                                             int selector) {
  ASSERT(!program()->is_compact());
  ThreadState* state = thread_state_;
  ASSERT(state != NULL);
  LookupCache* cache = state->cache();

  uword index = LookupCache::ComputeSecondaryIndex(clazz, selector);
  LookupCache::Entry* secondary = &(cache->secondary()[index]);
  if (secondary->clazz == clazz && secondary->selector == selector) {
    return secondary;
  }

  uword tag = 0;
  Function* target = clazz->LookupMethod(selector);
  if (target == NULL) {
    static const Names::Id name = Names::kNoSuchMethodTrampoline;
    target = clazz->LookupMethod(Selector::Encode(name, Selector::METHOD, 0));
  } else {
    void* intrinsic = target->ComputeIntrinsic();
    tag = (intrinsic == NULL) ? 1 : reinterpret_cast<uword>(intrinsic);
  }

  ASSERT(target != NULL);
  cache->DemotePrimary(primary);
  primary->clazz = clazz;
  primary->selector = selector;
  primary->target = target;
  primary->tag = tag;
  return primary;
}

NATIVE(ProcessQueueGetMessage) {
  PortQueue* queue = process->CurrentMessage();
  PortQueue::Kind kind = queue->kind();
  Object* result = Smi::FromWord(0);

  switch (kind) {
    case PortQueue::IMMEDIATE:
    case PortQueue::OBJECT:
      result = reinterpret_cast<Object*>(queue->address());
      break;

    case PortQueue::FOREIGN:
    case PortQueue::FOREIGN_FINALIZED: {
      Class* foreign_memory_class = process->program()->foreign_memory_class();
      ASSERT(foreign_memory_class->NumberOfInstanceFields() == 3);
      Object* object = process->NewInstance(foreign_memory_class);
      if (object == Failure::retry_after_gc()) return object;
      Instance* foreign = Instance::cast(object);
      uword address = queue->address();
      // TODO(ager): Two allocations in a native doesn't work with
      // the retry after gc strategy. We should restructure.
      object = process->ToInteger(address);
      if (object == Failure::retry_after_gc()) return object;
      foreign->SetInstanceField(0, object);
      int size = queue->size();
      foreign->SetInstanceField(1, Smi::FromWord(size));
      process->RecordStore(foreign, object);
      if (kind == PortQueue::FOREIGN_FINALIZED) {
        process->RegisterFinalizer(foreign, Process::FinalizeForeign);
        process->heap()->AllocatedForeignMemory(size);
      }
      result = foreign;
      break;
    }

    case PortQueue::EXIT: {
      ExitReference* ref = reinterpret_cast<ExitReference*>(queue->address());
      TakeExitReferenceHeaps(ref, process);
      result = ref->message();
      break;
    }

    default:
      UNREACHABLE();
  }

  process->AdvanceCurrentMessage();
  return result;
}

NATIVE(ProcessQueueGetChannel) {
  PortQueue* queue = process->CurrentMessage();
  // The channel for a port can die independently of the port. In that case
  // messages sent to the port can never be received. In that case we drop the
  // message when processing the message queue.
  while (queue != NULL) {
    Instance* channel = queue->port()->channel();
    if (channel != NULL) return channel;
    process->AdvanceCurrentMessage();
    queue = process->CurrentMessage();
  }
  return process->program()->null_object();
}

}  // namespace fletch
