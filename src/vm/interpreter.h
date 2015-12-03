// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_INTERPRETER_H_
#define SRC_VM_INTERPRETER_H_

#include "src/shared/globals.h"

#include "src/vm/lookup_cache.h"
#include "src/vm/natives.h"
#include "src/vm/process.h"

namespace fletch {

class Coroutine;
class Failure;
class Function;
class Port;

class TargetYieldResult {
 public:
  explicit TargetYieldResult(const Object* object)
      : value_(reinterpret_cast<uword>(object)) { }

  TargetYieldResult(Port* port, bool terminate)
      : value_(reinterpret_cast<uword>(port) |
               Terminate::encode(terminate)) { }

  bool ShouldTerminate() const { return Terminate::decode(value_); }

  Port* port() const {
    return reinterpret_cast<Port*>(value_ & ~Terminate::mask());
  }

  Object* AsObject() const { return reinterpret_cast<Object*>(value_); }

 private:
  class Terminate : public BoolField<0> {};

  uword value_;
};

class Interpreter {
 public:
  // This enum needs to be kept in sync with the corresponding enum in
  // lib/system/system.dart.
  enum InterruptKind {
    kReady,
    kTerminate,
    kImmutableAllocationFailure,
    kInterrupt,
    kYield,
    kTargetYield,
    kUncaughtException,
    kCompileTimeError,
    kBreakPoint
  };

  explicit Interpreter(Process* process)
      : process_(process),
        interruption_(kReady),
        target_yield_result_(NULL, false) { }

  // Run the Process until interruption.
  void Run();

  bool IsTerminated() const { return interruption_ == kTerminate; }
  bool IsImmutableAllocationFailure() const {
    return interruption_ == kImmutableAllocationFailure;
  }
  bool IsInterrupted() const { return interruption_ == kInterrupt; }
  bool IsYielded() const { return interruption_ == kYield; }
  bool IsTargetYielded() const { return interruption_ == kTargetYield; }
  bool IsUncaughtException() const {
    return interruption_ == kUncaughtException;
  }
  bool IsCompileTimeError() const { return interruption_ == kCompileTimeError; }
  bool IsAtBreakPoint() const { return interruption_ == kBreakPoint; }

  TargetYieldResult target_yield_result() const { return target_yield_result_; }

 private:
  InterruptKind HandleBailout();

  Process* const process_;
  InterruptKind interruption_;
  TargetYieldResult target_yield_result_;
};


// -------------------- Native interpreter support --------------------
//
// TODO(kasperl): Move this elsewhere? This is only here to support the
// native interpreter.

extern "C" const NativeFunction kNativeTable[];

extern "C" Process::StackCheckResult HandleStackOverflow(Process* process,
                                                         int size);

extern "C" int HandleGC(Process* process);

extern "C" Object* HandleAllocate(Process* process,
                                  Class* clazz,
                                  int immutable,
                                  int has_immutable_heapobject_member);

extern "C" void AddToStoreBufferSlow(Process* process,
                                     Object* object,
                                     Object* value);

extern "C" Object* HandleAllocateBoxed(Process* process, Object* value);

extern "C" Object* HandleObjectFromFailure(Process* process, Failure* failure);

extern "C" void HandleCoroutineChange(Process* process, Coroutine* coroutine);

extern "C" Object* HandleIdentical(Process* process,
                                   Object* left,
                                   Object* right);

extern "C" LookupCache::Entry* HandleLookupEntry(Process* process,
                                                 LookupCache::Entry* primary,
                                                 Class* clazz,
                                                 int selector);

extern "C" uint8* HandleThrow(Process* process,
                              Object* exception,
                              int* stack_delta_result,
                              Object*** frame_pointer_result);

extern "C" void HandleEnterNoSuchMethod(Process* process);

extern "C" void HandleInvokeSelector(Process* process);

extern "C" int HandleAtBytecode(Process* process, uint8* bcp, Object** sp);

}  // namespace fletch

#endif  // SRC_VM_INTERPRETER_H_
