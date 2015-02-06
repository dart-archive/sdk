// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROCESS_QUEUE_H_
#define SRC_VM_PROCESS_QUEUE_H_

#include <atomic>

#include "src/shared/assert.h"
#include "src/vm/process.h"

namespace fletch {

class ThreadState;

class ProcessQueue {
 public:
  ProcessQueue() : head_(NULL), tail_(NULL), size_(0) { }

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
    ASSERT(entry->queue_ == NULL);
    Process* head = head_;
    while (true) {
      if (head == kSentinel) return false;
      if (head_.compare_exchange_weak(head, kSentinel)) break;
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    ++size_;
    entry->queue_ = this;
    if (was_empty != NULL) *was_empty = head == NULL;
    if (head != NULL) {
      tail_.load()->queue_next_ = entry;
      entry->queue_previous_ = tail_.load();
      tail_ = entry;
      head_ = head;
    } else {
      tail_ = entry;
      head_ = entry;
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
    Process* head = head_;
    while (true) {
      if (head == kSentinel) return false;
      if (head == NULL) return true;
      if (head_.compare_exchange_weak(head, kSentinel)) break;
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    --size_;
    if (tail_ == head) {
      tail_ = NULL;
    }
    Process* next = head->queue_next_.load();
    if (next != NULL) next->queue_previous_ = NULL;
    if (!head->ChangeState(Process::kReady, Process::kRunning)) {
      UNIMPLEMENTED();
    }
    head->queue_ = NULL;
    head->queue_next_ = NULL;
    head->queue_previous_ = NULL;
    head_ = next;
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
    Process* head = head_;
    while (true) {
      if (head == kSentinel || head == NULL) return false;
      if (head_.compare_exchange_weak(head, kSentinel)) break;
    }
    ASSERT(head != kSentinel);
    ASSERT(head_ == kSentinel);
    if (entry->queue_ != this) {
      head_ = head;
      return false;
    }
    // We have now succesfully 'locked' the right queue - no entries can be
    // either added or removed at this point.
    if (!entry->ChangeState(Process::kReady, Process::kRunning)) {
      head_ = head;
      return false;
    }
    --size_;
    // At this point, the entry is 'taken' (marked as running) and can now
    // safely be removed from the queue.
    if (head == entry) {
      if (head == tail_) tail_ = NULL;
      head = head->queue_next_.load();
    } else {
      Process* next = entry->queue_next_.load();
      Process* prev = entry->queue_previous_.load();
      ASSERT(prev != NULL);
      prev->queue_next_ = next;
      if (next == NULL) {
        ASSERT(tail_ == entry);
        tail_ = prev;
      } else {
        next->queue_previous_ = prev;
      }
    }
    entry->queue_ = NULL;
    entry->queue_next_ = NULL;
    entry->queue_previous_ = NULL;
    head_ = head;
    return true;
  }

  bool is_empty() const { return size_ == 0; }

 private:
  Process* const kSentinel = reinterpret_cast<Process*>(1);

  std::atomic<Process*> head_;
  std::atomic<Process*> tail_;
  std::atomic<int> size_;
};

}  // namespace fletch

#endif  // SRC_VM_PROCESS_QUEUE_H_
