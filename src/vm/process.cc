// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/process.h"

#include <errno.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

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
  ExitReference(Space* space, Object* message)
      : space_(space), message_(message) { }

  ~ExitReference() {
    delete space_;
  }

  Object* message() const { return message_; }

  Space* TakeSpace() {
    Space* result = space_;
    space_ = NULL;
    return result;
  }

 private:
  Space* space_;
  Object* const message_;
};

class PortQueue {
 public:
  enum Kind {
    IMMEDIATE,
    PORT,
    LARGE_INTEGER,
    OBJECT,
    FOREIGN,
    FOREIGN_FINALIZED,
    EXIT
  };

  PortQueue(Port* port, int64 value, int size, Kind kind)
      : port_(port),
        value_(value),
        next_(NULL),
        kind_and_size_(KindField::encode(kind) | SizeField::encode(size)) {
    port_->IncrementRef();
    if (kind == PORT) {
      reinterpret_cast<Port*>(value_)->IncrementRef();
    }
  }

  ~PortQueue() {
    port_->DecrementRef();
    if (kind() == PORT) {
      reinterpret_cast<Port*>(value_)->DecrementRef();
    } else if (kind() == EXIT) {
      ExitReference* ref = reinterpret_cast<ExitReference*>(address());
      delete ref;
    }
  }

  Port* port() const { return port_; }
  int64 value() const { ASSERT(kind() == LARGE_INTEGER); return value_; }
  uword address() const { ASSERT(kind() != LARGE_INTEGER); return value_; }
  int size() const { return SizeField::decode(kind_and_size_); }
  Kind kind() const { return KindField::decode(kind_and_size_); }

  PortQueue* next() const { return next_; }
  void set_next(PortQueue* next) { next_ = next; }

  void VisitPointers(PointerVisitor* visitor) {
    if (kind() == OBJECT) {
      visitor->Visit(reinterpret_cast<Object**>(&value_));
    }
  }

 private:
  Port* port_;
  int64 value_;
  PortQueue* next_;
  class KindField: public BitField<Kind, 0, 3> { };
  class SizeField: public BitField<int, 3, 32 - 3> { };
  const int32 kind_and_size_;
};

ThreadState::ThreadState()
    : thread_id_(-1),
      queue_(new ProcessQueue()),
      cache_(new LookupCache()),
      idle_monitor_(Platform::CreateMonitor()),
      next_idle_thread_(NULL) {
}

void ThreadState::AttachToCurrentThread() {
  thread_ = ThreadIdentifier();
}

ThreadState::~ThreadState() {
  delete idle_monitor_;
  delete queue_;
  delete cache_;
}

Process::Process(Program* program)
    : heap_(4 * KB),
      program_(program),
      statics_(NULL),
      coroutine_(NULL),
      stack_limit_(NULL),
      state_(kSleeping),
      thread_state_(NULL),
      primary_lookup_cache_(NULL),
      next_(NULL),
      queue_(NULL),
      queue_next_(NULL),
      queue_previous_(NULL),
      ports_(NULL),
      weak_pointers_(NULL),
      last_message_(NULL),
      current_message_(NULL),
      program_gc_state_(kUnknown),
      errno_cache_(0),
      debug_info_(NULL) {
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
  ASSERT(next_ == NULL);
  ASSERT(cooked_stack_deltas_.is_empty());
  // Clear out the process pointer from all the ports.
  WeakPointer::ForceCallbacks(&weak_pointers_);
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
  Session* session = program()->session();
  if (session != NULL) {
    session->ProcessTerminated(this);
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
}

bool Process::HandleStackOverflow(int addition) {
  Object** current_limit = stack_limit();

  if (current_limit == kProfileMarker) {
    stack_limit_ = NULL;
    UpdateStackLimit();
    return true;
  }

  // When the stack_limit is kPreemptMarker, the process has been explicitly
  // asked to preempt.
  if (current_limit == kPreemptMarker) {
    stack_limit_ = NULL;
    UpdateStackLimit();
    return false;
  }

  int size_increase = Utils::RoundUpToPowerOfTwo(addition);
  size_increase = Utils::Maximum(256, size_increase);
  int new_size = stack()->length() + size_increase;
  if (new_size >= 32768) FATAL("Stack overflow");

  Object* new_stack_object = NewStack(new_size);
  if (new_stack_object == Failure::retry_after_gc()) {
    CollectGarbage();
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
  UpdateStackLimit();
  return true;
}

Object* Process::NewArray(int length) {
  Class* array_class = program()->array_class();
  Object* null = program()->null_object();
  Object* result = heap_.CreateArray(array_class, length, null);
  return result;
}

Object* Process::NewDouble(double value) {
  Class* double_class = program()->double_class();
  Object* result = heap_.CreateDouble(double_class, value);
  return result;
}

Object* Process::NewInteger(int64 value) {
  Class* large_integer_class = program()->large_integer_class();
  Object* result = heap_.CreateLargeInteger(large_integer_class, value);
  return result;
}

Object* Process::NewString(int length) {
  Class* string_class = program()->string_class();
  Object* raw_result = heap_.CreateString(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return String::cast(raw_result);
}

Object* Process::NewStringUninitialized(int length) {
  Class* string_class = program()->string_class();
  Object* raw_result = heap_.CreateStringUninitialized(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  return String::cast(raw_result);
}

Object* Process::NewStringFromAscii(List<const char> value) {
  Class* string_class = program()->string_class();
  Object* raw_result = heap_.CreateString(string_class, value.length());
  if (raw_result->IsFailure()) return raw_result;
  String* result = String::cast(raw_result);
  for (int i = 0; i < value.length(); i++) {
    result->set_code_unit(i, value[i]);
  }
  return result;
}

Object* Process::NewBoxed(Object* value) {
  Class* boxed_class = program()->boxed_class();
  Object* result = heap_.CreateBoxed(boxed_class, value);
  return result;
}

Object* Process::NewInstance(Class* klass) {
  Object* null = program()->null_object();
  Object* result = heap_.CreateHeapObject(klass, null);
  return result;
}

Object* Process::ToInteger(int64 value) {
  return Smi::IsValid(value)
      ? Smi::FromWord(value)
      : NewInteger(value);
}

Object* Process::Concatenate(String* x, String* y) {
  int xlen = x->length();
  int ylen = y->length();
  int length = xlen + ylen;
  Class* string_class = program()->string_class();
  Object* raw_result = heap_.CreateString(string_class, length);
  if (raw_result->IsFailure()) return raw_result;
  String* result = String::cast(raw_result);
  uint8_t* first_part = result->byte_address_for(0);
  uint8_t* second_part = first_part + xlen * sizeof(uint16_t);
  memcpy(first_part, x->byte_address_for(0), xlen * sizeof(uint16_t));
  memcpy(second_part, y->byte_address_for(0), ylen * sizeof(uint16_t));
  return result;
}

Object* Process::NewStack(int length) {
  Class* stack_class = program()->stack_class();
  Object* result = heap_.CreateStack(stack_class, length);
  return result;
}

void Process::CollectGarbage() {
  Space* to = new Space();
  // While garbage collecting, do not fail allocations. Instead grow
  // the to-space as needed.
  NoAllocationFailureScope scope(to);
  ScavengeVisitor visitor(heap_.space(), to);
  visitor.Visit(reinterpret_cast<Object**>(&statics_));
  visitor.Visit(reinterpret_cast<Object**>(&coroutine_));
  if (debug_info_ != NULL) debug_info_->VisitPointers(&visitor);
  to->CompleteScavenge(&visitor);
  WeakPointer::Process(&weak_pointers_);
  set_ports(Port::CleanupPorts(ports()));
  heap_.ReplaceSpace(to);
  UpdateStackLimit();
}

static void LinkProcessIfUnknownToProgramGC(Process* process, Process** list) {
  if (process != NULL &&
      process->program_gc_state() == Process::kUnknown) {
    ASSERT(process->next() == NULL)
    process->set_program_gc_state(Process::kFound);
    process->set_next(*list);
    *list = process;
  }
}

// Helper class for copying HeapObjects and chaining stacks for a
// process..
class ScavengeAndChainStacksVisitor: public PointerVisitor {
 public:
  ScavengeAndChainStacksVisitor(Process* process,
                                Space* from,
                                Space* to,
                                Process** list)
      : process_(process),
        from_(from),
        to_(to),
        number_of_stacks_(0),
        process_list_(list) { }

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

  void ChainPort(Instance* instance) {
    uword address = AsForeignWord(instance->GetInstanceField(0));
    Port* port = reinterpret_cast<Port*>(address);
    LinkProcessIfUnknownToProgramGC(port->process(), process_list_);
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
      } else if ((*p)->IsPort()) {
        ChainPort(Instance::cast(*p));
      }
    }
  }

  Process* process_;
  Space* from_;
  Space* to_;
  int number_of_stacks_;
  Process** process_list_;
};

int Process::CollectGarbageAndChainStacks(Process** list) {
  Space* to = new Space();
  // While garbage collecting, do not fail allocations. Instead grow
  // the to-space as needed.
  NoAllocationFailureScope scope(to);
  ScavengeAndChainStacksVisitor visitor(this, heap_.space(), to, list);
  // Visit the current coroutine stack first and chain the rest of the
  // stacks starting from there.
  visitor.Visit(reinterpret_cast<Object**>(coroutine_->stack_address()));
  visitor.Visit(reinterpret_cast<Object**>(&coroutine_));
  visitor.Visit(reinterpret_cast<Object**>(&statics_));
  to->CompleteScavenge(&visitor);
  WeakPointer::Process(&weak_pointers_);
  set_ports(Port::CleanupPorts(ports()));
  heap_.ReplaceSpace(to);
  // Update stack_limit.
  UpdateStackLimit();
  return visitor.number_of_stacks();
}

class ProgramPointerVisitor : public HeapObjectVisitor {
 public:
  explicit ProgramPointerVisitor(PointerVisitor* visitor)
      : visitor_(visitor) { }

  virtual void Visit(HeapObject* object) {
    object->IteratePointers(visitor_);
  }

 private:
  PointerVisitor* visitor_;
};

static void IteratePortQueueProgramPointers(PortQueue* queue,
                                            PointerVisitor* visitor) {
  for (PortQueue* current = queue;
       current != NULL;
       current = current->next()) {
     current->VisitPointers(visitor);
  }
}

void Process::IterateProgramPointers(PointerVisitor* visitor) {
  ProgramPointerVisitor program_pointer_visitor(visitor);
  heap()->IterateObjects(&program_pointer_visitor);
  if (debug_info_ != NULL) debug_info_->VisitProgramPointers(visitor);
  IteratePortQueueProgramPointers(last_message_, visitor);
  IteratePortQueueProgramPointers(current_message_, visitor);
}

static void CollectProcessesInQueue(PortQueue* queue, Process** list) {
  for (PortQueue* current = queue;
       current != NULL;
       current = current->next()) {
    if (current->kind() == PortQueue::PORT) {
      Port* port = reinterpret_cast<Port*>(current->address());
      LinkProcessIfUnknownToProgramGC(port->process(), list);
    }
  }
}

void Process::CollectProcessesInQueues(Process** list) {
  CollectProcessesInQueue(last_message_, list);
  CollectProcessesInQueue(current_message_, list);
}

void Process::TakeLookupCache() {
  ASSERT(primary_lookup_cache_ == NULL);
  ThreadState* state = thread_state_;
  ASSERT(state != NULL);
  primary_lookup_cache_ = state->cache()->primary();
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

void Process::DetachDebugger() {
  ASSERT(debug_info_ != NULL);
  delete debug_info_;
  debug_info_ = NULL;
}

void Process::PrepareStepOver() {
  Object** pushed_bcp_address = stack()->Pointer(stack()->top());
  uint8_t* current_bcp = reinterpret_cast<uint8_t*>(*pushed_bcp_address);
  Object** stack_top = pushed_bcp_address - 1;
  Opcode opcode = static_cast<Opcode>(*current_bcp);

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
    case Opcode::kInvokeEq:
    case Opcode::kInvokeLt:
    case Opcode::kInvokeLe:
    case Opcode::kInvokeGt:
    case Opcode::kInvokeGe:
    case Opcode::kInvokeAdd:
    case Opcode::kInvokeSub:
    case Opcode::kInvokeMod:
    case Opcode::kInvokeMul:
    case Opcode::kInvokeTruncDiv:
    case Opcode::kInvokeBitNot:
    case Opcode::kInvokeBitAnd:
    case Opcode::kInvokeBitOr:
    case Opcode::kInvokeBitXor:
    case Opcode::kInvokeBitShr:
    case Opcode::kInvokeBitShl:
      stack_diff = Bytecode::StackDiff(opcode);
      break;
    default:
      ASSERT(opcode < Bytecode::kNumBytecodes);
      // For any other bytecode step over is the same as step.
      debug_info_->set_is_stepping(true);
      return;
  }

  Object** expected_sp = stack_top + stack_diff;
  Function* function = Function::FromBytecodePointer(current_bcp);
  int stack_height = expected_sp - stack()->Pointer(0);
  int bytecode_index =
      current_bcp + Bytecode::Size(opcode) - function->bytecode_address_for(0);
  debug_info_->SetStepOverBreakpoint(function,
                                     bytecode_index,
                                     coroutine_,
                                     stack_height);
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
  PortQueue* entry;
  if (!message->IsHeapObject()) {
    uword address = reinterpret_cast<uword>(message);
    entry = new PortQueue(port, address, 0, PortQueue::IMMEDIATE);
  } else if (message->IsPort()) {
    Instance* instance = Instance::cast(message);
    uword address = AsForeignWord(instance->GetInstanceField(0));
    entry = new PortQueue(port, address, 0, PortQueue::PORT);
  } else if (message->IsLargeInteger()) {
    int64 value = LargeInteger::cast(message)->value();
    entry = new PortQueue(port, value, 0, PortQueue::LARGE_INTEGER);
  } else {
    Space* space = program_->heap()->space();
    if (!space->Includes(HeapObject::cast(message)->address())) return false;
    uword address = reinterpret_cast<uword>(message);
    entry = new PortQueue(port, address, 0, PortQueue::OBJECT);
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
  Space* space = sender->heap()->TakeSpace();
  uword address = reinterpret_cast<uword>(new ExitReference(space, message));
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
  weak_pointers_ = new WeakPointer(object, callback, weak_pointers_);
}

void Process::UnregisterFinalizer(HeapObject* object) {
  WeakPointer::Remove(&weak_pointers_, object);
}

void Process::FinalizeForeign(HeapObject* foreign) {
  Instance* instance = Instance::cast(foreign);
  word value = AsForeignWord(instance->GetInstanceField(0));
  free(reinterpret_cast<void*>(value));
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

    case PortQueue::PORT: {
      Class* port_class = process->program()->port_class();
      ASSERT(port_class->NumberOfInstanceFields() == 1);
      Object* object = process->NewInstance(port_class);
      if (object == Failure::retry_after_gc()) return object;
      Instance* port = Instance::cast(object);
      uword address = queue->address();
      // TODO(kasperl): This really doesn't work. We cannot do
      // two allocations within a single native call with the
      // retry-after-GC strategy we're currently employing.
      object = process->ToInteger(address);
      if (object == Failure::retry_after_gc()) return object;
      reinterpret_cast<Port*>(address)->IncrementRef();
      process->RegisterFinalizer(port, Port::WeakCallback);
      port->SetInstanceField(0, object);
      result = port;
      break;
    }

    case PortQueue::LARGE_INTEGER:
      result = process->NewInteger(queue->value());
      if (result == Failure::retry_after_gc()) return result;
      break;

    case PortQueue::FOREIGN:
    case PortQueue::FOREIGN_FINALIZED: {
      Class* foreign_class = process->program()->foreign_class();
      ASSERT(foreign_class->NumberOfInstanceFields() == 2);
      Object* object = process->NewInstance(foreign_class);
      if (object == Failure::retry_after_gc()) return object;
      Instance* foreign = Instance::cast(object);
      uword address = queue->address();
      // TODO(ager): Two allocations in a native doesn't work with
      // the retry after gc strategy. We should restructure.
      object = process->ToInteger(address);
      if (object == Failure::retry_after_gc()) return object;
      foreign->SetInstanceField(0, object);
      foreign->SetInstanceField(1, Smi::FromWord(queue->size()));
      if (kind == PortQueue::FOREIGN_FINALIZED) {
        process->RegisterFinalizer(foreign, Process::FinalizeForeign);
      }
      result = foreign;
      break;
    }

    case PortQueue::EXIT: {
      ExitReference* ref = reinterpret_cast<ExitReference*>(queue->address());
      process->heap()->space()->PrependSpace(ref->TakeSpace());
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
