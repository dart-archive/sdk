// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_HANDLE_H_
#define SRC_VM_PROCESS_HANDLE_H_

#include "src/shared/platform.h"

#include "src/vm/spinlock.h"
#include "src/vm/refcounted.h"

namespace dartino {

class Process;
class Object;

class ProcessHandle : public Refcounted<ProcessHandle> {
 public:
  explicit ProcessHandle(Process* process) : process_(process) {}

  Spinlock* lock() { return &spinlock_; }

  Process* process() const { return process_; }

  // Gets the pointer to a process handle out of the first field of 'o', which
  // should be an instance of program->process_class().
  static ProcessHandle* FromDartObject(Object* o);

  // Puts a pointer to 'this' in the first field of the object, which should be
  // an instance of program->process_class().
  void InitializeDartObject(Object* o);

 private:
  friend class Process;

  void OwnerProcessTerminating() {
    ScopedSpinlock locker(&spinlock_);
    ASSERT(process_ != NULL);
    process_ = NULL;
  }

  Process* process_;
  Spinlock spinlock_;
};

}  // namespace dartino

#endif  // SRC_VM_PROCESS_HANDLE_H_
