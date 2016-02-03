// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_QUEUE_H_
#define SRC_VM_PROCESS_QUEUE_H_

#include "src/shared/assert.h"
#include "src/shared/atomic.h"

#include "src/vm/process.h"

namespace dartino {

class ThreadState;

class ProcessQueue {
 public:
  ProcessQueue() : head_(NULL), tail_(NULL) {}

  // Try to enqueue [entry].
  // Returns false if it was not possible to modify the queue. The operation
  // should be repeated.
  // Returns true if [entry] was successfully enqueued. In this case, the
  // [entry] will have its queue_ set to this.
  bool TryEnqueue(Process* entry, bool* was_empty = NULL) {
    ASSERT(entry != NULL);
    ASSERT(entry != kSentinel);
    ASSERT(entry->queue_next_ == NULL);
    ASSERT(entry->queue_previous_ == NULL);
    ASSERT(entry->queue_.load() == NULL);
    Process* head = head_.load(kRelaxed);
    while (true) {
      if (head == kSentinel) return false;
      if (head_.compare_exchange_weak(head, kSentinel, kAcquire, kRelaxed)) {
        break;
      }
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    entry->queue_.store(this, kRelease);
    if (was_empty != NULL) *was_empty = head == NULL;
    if (head != NULL) {
      tail_->queue_next_ = entry;
      entry->queue_previous_ = tail_;
      tail_ = entry;
      head_.store(head, kRelease);
    } else {
      tail_ = entry;
      head_.store(entry, kRelease);
    }
    return true;
  }

  // Try to dequeue the next entry.
  // Returns false if it was not possible to modify the queue. The operation
  // should be repeated.
  // Returns true if an entry was successfully dequeued (or the queue is empty).
  // In this case, the queue_ of the entry will be set to NULL.
  bool TryDequeue(Process** entry) {
    ASSERT(*entry == NULL);
    Process* head = head_.load(kRelaxed);
    while (true) {
      if (head == kSentinel) return false;
      if (head == NULL) return true;
      if (head_.compare_exchange_weak(head, kSentinel, kAcquire, kRelaxed)) {
        break;
      }
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    if (tail_ == head) {
      tail_ = NULL;
    }
    Process* next = head->queue_next_;
    if (next != NULL) next->queue_previous_ = NULL;
    if (!head->ChangeState(Process::kReady, Process::kRunning)) {
      UNIMPLEMENTED();
    }
    head->queue_.store(NULL, kRelaxed);
    head->queue_next_ = NULL;
    head->queue_previous_ = NULL;
    head_.store(next, kRelease);
    *entry = head;
    return true;
  }

  // Try to dequeue [entry] from the queue.
  // If [thread_state] is not equal to [entry]'s thread state, or [entry] is not
  // available for running, the operation will fail.
  // Returns false if entry was not dequeued.
  // Returns true if entry was succesfully dequeued and had its queue_
  // set to NULL and been marked for running.
  bool TryDequeueEntry(Process* entry) {
    ASSERT(entry != NULL);
    Process* head = head_.load(kRelaxed);
    while (true) {
      if (head == kSentinel || head == NULL) return false;
      if (head_.compare_exchange_weak(head, kSentinel, kAcquire, kRelaxed)) {
        break;
      }
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    if (entry->queue_ != this) {
      head_.store(head, kRelease);
      return false;
    }
    // We have now succesfully 'locked' the right queue - no entries can be
    // either added or removed at this point.
    if (!entry->ChangeState(Process::kReady, Process::kRunning)) {
      head_.store(head, kRelease);
      return false;
    }
    // At this point, the entry is 'taken' (marked as running) and can now
    // safely be removed from the queue.
    if (head == entry) {
      if (head == tail_) tail_ = NULL;
      head = head->queue_next_;
    } else {
      Process* next = entry->queue_next_;
      Process* prev = entry->queue_previous_;
      ASSERT(prev != NULL);
      prev->queue_next_ = next;
      if (next == NULL) {
        ASSERT(tail_ == entry);
        tail_ = prev;
      } else {
        next->queue_previous_ = prev;
      }
    }
    entry->queue_.store(NULL, kRelaxed);
    entry->queue_next_ = NULL;
    entry->queue_previous_ = NULL;
    head_.store(head, kRelease);
    return true;
  }

  bool is_empty() const { return head_.load(kAcquire) == NULL; }

 private:
  Process* const kSentinel = reinterpret_cast<Process*>(1);

  Atomic<Process*> head_;
  // The tail_ field is only modified under a lock on head_. This gives us the
  // right memory-order on tail_, without read/writes being explicit atomic.
  Process* tail_;
};

}  // namespace dartino

#endif  // SRC_VM_PROCESS_QUEUE_H_
