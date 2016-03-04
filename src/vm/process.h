// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_H_
#define SRC_VM_PROCESS_H_

#include "src/shared/atomic.h"
#include "src/shared/random.h"

#include "src/vm/debug_info.h"
#include "src/vm/heap.h"
#include "src/vm/links.h"
#include "src/vm/lookup_cache.h"
#include "src/vm/message_mailbox.h"
#include "src/vm/natives.h"
#include "src/vm/process_handle.h"
#include "src/vm/program.h"
#include "src/vm/remembered_set.h"
#include "src/vm/signal.h"
#include "src/vm/thread.h"

namespace dartino {

class Engine;
class Interpreter;
class Port;
class ProcessQueue;
class ProcessVisitor;
class Session;

class Process : public ProcessList::Entry, public ProcessQueueList::Entry {
 public:
  enum State {
    kSleeping,
    kEnqueuing,
    kReady,
    kRunning,
    kYielding,
    kBreakpoint,
    kCompileTimeError,
    kUncaughtException,
    kTerminated,
    kWaitingForChildren,
  };

  static const char* StateToName(State state) {
    switch (state) {
      case kSleeping:
        return "kSleeping";
      case kEnqueuing:
        return "kEnqueuing";
      case kReady:
        return "kReady";
      case kRunning:
        return "kRunning";
      case kYielding:
        return "kYielding";
      case kBreakpoint:
        return "kBreakpoint";
      case kCompileTimeError:
        return "kCompileTimeError";
      case kUncaughtException:
        return "kUncaughtException";
      case kTerminated:
        return "kTerminated";
      case kWaitingForChildren:
        return "kWaitingForChildren";
    }
    return "Unknown";
  }

  enum StackCheckResult {
    // Stack check handled (most likely by growing the stack) and
    // execution can continue.
    kStackCheckContinue,
    // Interrupted for preemption.
    kStackCheckInterrupt,
    // Interrupted for debugging.
    kStackCheckDebugInterrupt,
    // Stack overflow.
    kStackCheckOverflow
  };

  Function* entry() { return program_->entry(); }
  Program* program() { return program_; }
  Array* statics() const { return statics_; }
  Object* exception() const { return exception_; }
  void set_exception(Object* object) { exception_ = object; }
  TwoSpaceHeap* heap() { return program()->process_heap(); }

  Coroutine* coroutine() const { return coroutine_; }
  void UpdateCoroutine(Coroutine* coroutine);

  Stack* stack() const { return coroutine_->stack(); }
  uword stack_limit() const { return stack_limit_.load(); }

  Port* ports() const { return ports_; }
  void set_ports(Port* port) { ports_ = port; }

  ProcessHandle* process_handle() const { return process_handle_; }
  Links* links() { return &links_; }

  Process* parent() const { return parent_; }

  // Returns false for allocation failure.
  static const int kInitialStackSize = 256;
  void SetupExecutionStack();
  StackCheckResult HandleStackOverflow(int addition);

  inline LookupCache::Entry* LookupEntry(Object* receiver, int selector);

  // Lookup and update the primary cache entry.
  LookupCache::Entry* LookupEntrySlow(LookupCache::Entry* primary, Class* clazz,
                                      int selector);

  Object* NewByteArray(int length);
  Object* NewArray(int length);
  Object* NewDouble(dartino_double value);
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

  void ValidateHeaps();

  // Iterate all pointers reachable from this process object.
  void IterateRoots(PointerVisitor* visitor);

  // Iterate all pointers in the process heap and stack. Used for
  // program garbage collection.
  void IterateProgramPointers(PointerVisitor* visitor);
  void IterateProgramPointersOnHeap(PointerVisitor* visitor);

  // Iterate over, and find pointers in the port queue.
  void IteratePortQueuesPointers(PointerVisitor* visitor);

  void SetStackMarker(uword marker);
  void ClearStackMarker(uword marker);
  void Preempt();
  void DebugInterrupt();

  // Debugging support.
  void EnsureDebuggerAttached();
  int PrepareStepOver();
  int PrepareStepOut();

  ProcessDebugInfo* debug_info() { return debug_info_; }
  bool is_debugging() const { return debug_info_ != NULL; }

  void TakeLookupCache();
  void ReleaseLookupCache() { primary_lookup_cache_ = NULL; }

  // Program GC support. Update breakpoints after having moved function.
  // Bytecode pointers need to be updated.
  void UpdateBreakpoints();

  // Change the state from 'from' to 'to. Return 'true' if the operation was
  // successful.
  inline bool ChangeState(State from, State to);
  State state() const { return state_; }

  void RegisterFinalizer(HeapObject* object, WeakPointerCallback callback);
  void RegisterExternalFinalizer(HeapObject* object,
                                 ExternalWeakPointerCallback callback,
                                 void* arg);
  void UnregisterFinalizer(HeapObject* object);
  bool UnregisterExternalFinalizer(HeapObject* object,
                                   ExternalWeakPointerCallback callback);

  static void FinalizeForeign(HeapObject* foreign, Heap* heap);
  static void FinalizeProcess(HeapObject* process, Heap* heap);

#ifdef DEBUG
  // This is used in order to return a retry after gc failure on every other
  // call to the GC native that is used for testing only.
  bool TrueThenFalse();

  void set_native_verifier(NativeVerifier* verifier) {
    native_verifier_ = verifier;
  }

  void RegisterProcessAllocation() {
    if (native_verifier_ != NULL) {
      native_verifier_->RegisterAllocation();
    }
  }
#else
  void RegisterProcessAllocation() {}
#endif

  void StoreErrno();
  void RestoreErrno();

  RandomXorShift* random() { return &random_; }

  MessageMailbox* mailbox() { return &mailbox_; }

  Signal* signal() { return signal_.load(); }

  void RecordStore(HeapObject* object, Object* value) {
    if (value->IsHeapObject()) {
      ASSERT(!program()->heap()->space()->Includes(object->address()));
      GCMetadata::InsertIntoRememberedSet(object->address());
    }
  }

  void SendSignal(Signal* signal);

  void PrintStackTrace() const;

  List<List<uint8>> arguments() { return arguments_; }
  void set_arguments(List<List<uint8>> arguments) { arguments_ = arguments; }

  // If you add an offset here, remember to add the corresponding static_assert
  // in process.cc.
  static const uword kNativeStackOffset = 4 * kWordSize;
  static const uword kCoroutineOffset = kNativeStackOffset + kWordSize;
  static const uword kStackLimitOffset = kCoroutineOffset + kWordSize;
  static const uword kProgramOffset = kStackLimitOffset + kWordSize;
  static const uword kStaticsOffset = kProgramOffset + kWordSize;
  static const uword kExceptionOffset = kStaticsOffset + kWordSize;
  static const uword kPrimaryLookupCacheOffset = kExceptionOffset + kWordSize;

  bool AllocationFailed() { return statics_ == NULL; }
  void SetAllocationFailed() { statics_ = NULL; }

 private:
  friend class Interpreter;
  friend class Engine;
  friend class Program;

  // Creation and deletion of processes is managed by a [Program].
  Process(Program* program, Process* parent);
  ~Process();

  // Must be called before deletion. After this method is done cleaning up,
  // no other processes will be able to send messages or signals to this
  // process.
  // The process is therefore invisble for anything else and can be safely
  // deleted.
  void Cleanup(Signal::Kind kind);

  void UpdateStackLimit();

  // Put these first so they can be accessed from the interpreter without
  // issues around object layout.
  void* native_stack_;
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

  Links links_;

  Atomic<State> state_;

  Atomic<Signal*> signal_;
  MessageMailbox mailbox_;

  ProcessHandle* process_handle_;

  // Linked list of ports owned by this process.
  Port* ports_;

  // The number of direct child processes plus 1.
  Atomic<int> process_triangle_count_;

  // Valid until this object gets deleted.
  Process* const parent_;

  int errno_cache_;

  ProcessDebugInfo* debug_info_;

  List<List<uint8>> arguments_;

#ifdef DEBUG
  bool true_then_false_;
  NativeVerifier* native_verifier_;
#endif
};

inline LookupCache::Entry* Process::LookupEntry(Object* receiver,
                                                int selector) {
  ASSERT(!program()->is_optimized());

  Class* clazz = receiver->IsSmi() ? program()->smi_class()
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

}  // namespace dartino

#endif  // SRC_VM_PROCESS_H_
