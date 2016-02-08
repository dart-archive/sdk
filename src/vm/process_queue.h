// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_QUEUE_H_
#define SRC_VM_PROCESS_QUEUE_H_

#include "src/shared/assert.h"

#include "src/vm/process.h"
#include "src/vm/program.h"
#include "src/vm/spinlock.h"

namespace dartino {

class ThreadState;

class ProcessQueue {
 public:
  // Enqueues [entry] to the queue and returns whether it was empty.
  bool Enqueue(Process* entry) {
    ScopedSpinlock locker(&spinlock_);
    ASSERT(!ready_.IsInList(entry));
    ASSERT(entry->state() == Process::kReady);
    bool was_empty = ready_.IsEmpty();
    ready_.Append(entry);
    return was_empty;
  }

  // Try to dequeue the next [entry] and returns if it was successful.
  bool TryDequeue(Process** entry) {
    ScopedSpinlock locker(&spinlock_);

    if (ready_.IsEmpty()) return false;

    Process* process = ready_.RemoveFirst();
    if (!process->ChangeState(Process::kReady, Process::kRunning)) {
      UNIMPLEMENTED();
    }
    *entry = process;
    return true;
  }

  // Dequeue [entry] from the ready queue and returns whether it was successful.
  bool TryDequeueEntry(Process* entry) {
    ScopedSpinlock locker(&spinlock_);

    if (entry->ChangeState(Process::kReady, Process::kRunning)) {
      ready_.Remove(entry);
      return true;
    }
    return false;
  }

  // Notice that by the return of the call, another thread might have already
  // enqueued more. The caller is responsible for guarding against that!
  bool IsEmpty() {
    ScopedSpinlock locker(&spinlock_);
    return ready_.IsEmpty();
  }

 private:
  Spinlock spinlock_;
  ProcessQueueList ready_;
};

}  // namespace dartino

#endif  // SRC_VM_PROCESS_QUEUE_H_
