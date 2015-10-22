// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_H_
#define SRC_VM_PROCESS_H_

#include "src/shared/atomic.h"
#include "src/shared/random.h"

#include "src/vm/debug_info.h"
#include "src/vm/heap.h"
#include "src/vm/lookup_cache.h"
#include "src/vm/message_mailbox.h"
#include "src/vm/process_handle.h"
#include "src/vm/program.h"
#include "src/vm/storebuffer.h"
#include "src/vm/thread.h"

namespace fletch {

class Engine;
class Interpreter;
class ImmutableHeap;
class Port;
class ProcessQueue;
class ProcessVisitor;

class ThreadState {
 public:
  ThreadState();
  ~ThreadState();

  int thread_id() const { return thread_id_; }
  void set_thread_id(int thread_id) {
    ASSERT(thread_id_ == -1);
    thread_id_ = thread_id;
  }

  const ThreadIdentifier* thread() const { return &thread_; }

  // Update the thread field to point to the current thread.
  void AttachToCurrentThread();

  ProcessQueue* queue() { return queue_; }

  LookupCache* cache() const { return cache_; }
  LookupCache* EnsureCache();

  Monitor* idle_monitor() const { return idle_monitor_; }

  ThreadState* next_idle_thread() const { return next_idle_thread_; }
  void set_next_idle_thread(ThreadState* value) { next_idle_thread_ = value; }

 private:
  int thread_id_;
  ThreadIdentifier thread_;
  ProcessQueue* const queue_;
  LookupCache* cache_;
  Monitor* idle_monitor_;
  Atomic<ThreadState*> next_idle_thread_;
};

class Process {
 public:
  enum State {
    kSleeping,
    kReady,
    kRunning,
    kYielding,
    kBreakPoint,
    kCompileTimeError,
    kUncaughtException,
    kTerminated,
  };

  enum ProgramGCState {
    kUnknown,
    kFound,
    kProcessed,
  };

  enum StackCheckResult {
    kStackCheckContinue,
    kStackCheckInterrupt,
    kStackCheckDebugInterrupt,
    kStackCheckOverflow
  };

  Function* entry() { return program_->entry(); }
  int main_arity() { return program_->main_arity(); }
  Program* program() { return program_; }
  Array* statics() const { return statics_; }
  Object* exception() const { return exception_; }
  void set_exception(Object* object) { exception_ = object; }
  Heap* heap() { return &heap_; }
  Heap* immutable_heap() { return immutable_heap_; }
  void set_immutable_heap(Heap* heap) { immutable_heap_ = heap; }

  Coroutine* coroutine() const { return coroutine_; }
  void UpdateCoroutine(Coroutine* coroutine);

  Stack* stack() const { return coroutine_->stack(); }
  uword stack_limit() const { return stack_limit_.load(); }

  Port* ports() const { return ports_; }
  void set_ports(Port* port) { ports_ = port; }

  ProcessHandle* process_handle() const { return process_handle_; }

  void SetupExecutionStack();
  StackCheckResult HandleStackOverflow(int addition);

  inline LookupCache::Entry* LookupEntry(Object* receiver, int selector);

  // Lookup and update the primary cache entry.
  LookupCache::Entry* LookupEntrySlow(LookupCache::Entry* primary,
                                      Class* clazz,
                                      int selector);

  Object* NewByteArray(int length);
  Object* NewArray(int length);
  Object* NewDouble(fletch_double value);
  Object* NewInteger(int64 value);

  // Attempt to deallocate the large integer object. If the large integer
  // was the last allocated object the allocation top is moved back so
  // the memory can be reused.
  void TryDeallocInteger(LargeInteger* object);

  // NewString allocates a string of the given length and fills the payload
  // with zeroes.
  Object* NewOneByteString(int length);
  Object* NewTwoByteString(int length);

  // New[One/Two]ByteStringUninitialized allocates a string of the given length
  // and leaves the payload uninitialized. The payload contains whatever
  // was in that heap space before. Only use this if you intend to
  // immediately overwrite the payload with something else.
  Object* NewOneByteStringUninitialized(int length);
  Object* NewTwoByteStringUninitialized(int length);

  Object* NewStringFromAscii(List<const char> value);
  Object* NewBoxed(Object* value);
  Object* NewStack(int length);

  Object* NewInstance(Class* klass, bool immutable = false);

  // Returns either a Smi or a LargeInteger.
  Object* ToInteger(int64 value);

  void CollectMutableGarbage();

  // Perform garbage collection and chain all stack objects. Additionally,
  // locate all processes in ports in the heap that are not yet known
  // by the program GC and link them in the argument list. Returns the
  // number of stacks found in the heap.
  int CollectMutableGarbageAndChainStacks();
  int CollectGarbageAndChainStacks();

  void ValidateHeaps(ImmutableHeap* immutable_heap);

  // Iterate all pointers reachable from this process object.
  void IterateRoots(PointerVisitor* visitor);

  // Iterate all pointers in the process heap and stack. Used for
  // program garbage collection.
  void IterateProgramPointers(PointerVisitor* visitor);

  // Iterate over, and find pointers in the port queue.
  void IteratePortQueuesPointers(PointerVisitor* visitor);

  void SetStackMarker(uword marker);
  void ClearStackMarker(uword marker);
  void Preempt();
  void DebugInterrupt();
  void Profile();

  // Debugging support.
  void AttachDebugger();
  int PrepareStepOver();
  int PrepareStepOut();

  DebugInfo* debug_info() { return debug_info_; }
  bool is_debugging() const { return debug_info_ != NULL; }

  Process* next() const { return next_; }
  void set_next(Process* process) { next_ = process; }

  void TakeLookupCache();
  void ReleaseLookupCache() { primary_lookup_cache_ = NULL; }

  // Program GC support. Cook the stack to rewrite bytecode pointers
  // to a pair of a function pointer and a delta. Uncook the stack to
  // rewriting the (now potentially moved) function pointer and the
  // delta into a direct bytecode pointer again.
  void CookStacks(int number_of_stacks);
  void UncookAndUnchainStacks();

  bool stacks_are_cooked() { return !cooked_stack_deltas_.is_empty(); }

  // Program GC support. Update breakpoints after having moved function.
  // Bytecode pointers need to be updated.
  void UpdateBreakpoints();

  // Change the state from 'from' to 'to. Return 'true' if the operation was
  // successful.
  inline bool ChangeState(State from, State to);
  State state() const { return state_; }

  ThreadState* thread_state() const { return thread_state_; }
  void set_thread_state(ThreadState* thread_state) {
    ASSERT(thread_state == NULL || thread_state_ == NULL);
    thread_state_ = thread_state;
  }

  void TakeChildHeaps();

  void RegisterFinalizer(HeapObject* object, WeakPointerCallback callback);
  void UnregisterFinalizer(HeapObject* object);

  static void FinalizeForeign(HeapObject* foreign, Heap* heap);
  static void FinalizeProcess(HeapObject* process, Heap* heap);

  // This is used in order to return a retry after gc failure on every other
  // call to the GC native that is used for testing only.
  bool TrueThenFalse();

  ProcessQueue* process_queue() const { return queue_; }

  void StoreErrno();
  void RestoreErrno();

  RandomXorShift* random() { return &random_; }

  StoreBuffer* store_buffer() { return &store_buffer_; }

  MessageMailbox* mailbox() { return &mailbox_; }

  void RecordStore(HeapObject* object, Object* value) {
    if (value->IsHeapObject() && value->IsImmutable()) {
      ASSERT(!program()->heap()->space()->Includes(
          object->address()));
      ASSERT(heap()->space()->Includes(
          object->address()));
      store_buffer_.Insert(object);
    }
  }

  // If you add an offset here, remember to add the corresponding static_assert
  // in process.cc.
  static const uword kCoroutineOffset = 0;
  static const uword kStackLimitOffset = kCoroutineOffset + sizeof(void*);
  static const uword kProgramOffset = kStackLimitOffset + sizeof(void*);
  static const uword kStaticsOffset = kProgramOffset + sizeof(void*);
  static const uword kExceptionOffset = kStaticsOffset + sizeof(void*);
  static const uword kPrimaryLookupCacheOffset =
      kExceptionOffset + sizeof(void*);

 private:
  friend class Interpreter;
  friend class Engine;
  friend class Program;

  // Creation and deletion of processes is managed by a [Program].
  explicit Process(Program* program);
  ~Process();

  // Must be called before deletion. After this method is done cleaning up,
  // no other processes will be able to send messages or signals to this
  // process.
  // The process is therefore invisble for anything else and can be safely
  // deleted.
  void Cleanup();

  void UpdateStackLimit();

  void set_process_list_next(Process* process) { process_list_next_ = process; }
  Process* process_list_next() { return process_list_next_; }
  void set_process_list_prev(Process* process) { process_list_prev_ = process; }
  Process* process_list_prev() { return process_list_prev_; }

  // Put these first so they can be accessed from the interpreter without
  // issues around object layout.
  Coroutine* coroutine_;
  Atomic<uword> stack_limit_;
  Program* program_;
  Array* statics_;
  Object* exception_;

  // We need extremely fast access to the primary lookup cache, so we
  // store a reference to it in the process whenever we're interpreting
  // code in this process.
  LookupCache::Entry* primary_lookup_cache_;

  RandomXorShift random_;

  Heap heap_;
  Heap* immutable_heap_;
  StoreBuffer store_buffer_;

  Atomic<State> state_;
  Atomic<ThreadState*> thread_state_;

  List<List<int> > cooked_stack_deltas_;

  // Next pointer used by the Scheduler.
  Process* next_;

  // Fields used by ProcessQueue, when holding the Process.
  friend class ProcessQueue;
  Atomic<ProcessQueue*> queue_;
  // While the ProcessQueue is lock-free, we have an 'atomic lock' on the
  // head_ element. That will ensure we have the right memory order on
  // queue_next_/queue_previous_, as they are always read/modified while
  // head_ is 'locked'.
  Process* queue_next_;
  Process* queue_previous_;

  ProcessHandle* process_handle_;

  // Linked list of ports owned by this process.
  Port* ports_;

  MessageMailbox mailbox_;

  // Used for chaining all processes of a program. It is protected by a lock
  // in the program.
  Process* process_list_next_;
  Process* process_list_prev_;

  int errno_cache_;

  DebugInfo* debug_info_;

#ifdef DEBUG
  bool true_then_false_;
#endif
};

inline LookupCache::Entry* Process::LookupEntry(Object* receiver,
                                                int selector) {
  ASSERT(!program()->is_compact());

  Class* clazz = receiver->IsSmi()
      ? program()->smi_class()
      : HeapObject::cast(receiver)->get_class();
  ASSERT(primary_lookup_cache_ != NULL);

  uword index = LookupCache::ComputePrimaryIndex(clazz, selector);
  LookupCache::Entry* primary = &(primary_lookup_cache_[index]);
  return (primary->clazz == clazz && primary->selector == selector)
      ? primary
      : LookupEntrySlow(primary, clazz, selector);
}

inline bool Process::ChangeState(State from, State to) {
  if (from == kRunning || from == kYielding) {
    ASSERT(thread_state_ == NULL);
    ASSERT(state_ == from);
    state_ = to;
    return true;
  }
  State value = state_;
  while (true) {
    if (value == kYielding) {
      value = state_;
      continue;
    }
    if (value != from) break;
    if (state_.compare_exchange_weak(value, to)) return true;
  }
  return false;
}

}  // namespace fletch

#endif  // SRC_VM_PROCESS_H_
