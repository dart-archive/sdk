// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_HANDLE_H_
#define SRC_VM_PROCESS_HANDLE_H_

#include "src/shared/platform.h"

#include "src/vm/spinlock.h"
#include "src/vm/refcounted.h"

namespace fletch {

class Process;

class ProcessHandle : public Refcounted<ProcessHandle> {
 public:
  explicit ProcessHandle(Process* process) : process_(process) {}

  Spinlock* lock() { return &spinlock_; }

  Process* process() const { return process_; }

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

}  // namespace fletch

#endif  // SRC_VM_PROCESS_HANDLE_H_
