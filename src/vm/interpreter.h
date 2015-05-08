// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_INTERPRETER_H_
#define SRC_VM_INTERPRETER_H_

#include "src/shared/globals.h"

#include "src/vm/lookup_cache.h"
#include "src/vm/natives.h"

namespace fletch {

class Coroutine;
class Failure;
class Function;
class Port;
class Process;

class Interpreter {
 public:
  enum InterruptKind {
    kReady,
    kTerminate,
    kInterrupt,
    kYield,
    kTargetYield,
    kUncaughtException,
    kBreakPoint
  };

  explicit Interpreter(Process* process)
      : process_(process),
        interruption_(kReady),
        target_(NULL) { }

  // Run the Process until interruption.
  void Run();

  bool IsTerminated() const { return interruption_ == kTerminate; }
  bool IsInterrupted() const { return interruption_ == kInterrupt; }
  bool IsYielded() const { return interruption_ == kYield; }
  bool IsTargetYielded() const { return interruption_ == kTargetYield; }
  bool IsUncaughtException() const {
    return interruption_ == kUncaughtException;
  }
  bool IsAtBreakPoint() const { return interruption_ == kBreakPoint; }

  Port* target() const { return target_; }

 private:
  Process* const process_;
  InterruptKind interruption_;
  Port* target_;
};


// -------------------- Native interpreter support --------------------
//
// TODO(kasperl): Move this elsewhere? This is only here to support the
// native interpreter.

extern "C" const NativeFunction kNativeTable[];

extern "C" bool HandleIsInvokeFast(int opcode);

extern "C" bool HandleStackOverflow(Process* process, int size);

extern "C" void HandleGC(Process* process);

extern "C" Object* HandleAllocate(Process* process, Class* clazz,
                                  int immutable);

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
                              int* stack_delta);


}  // namespace fletch

#endif  // SRC_VM_INTERPRETER_H_
