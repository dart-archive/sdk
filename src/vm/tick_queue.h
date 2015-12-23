// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_TICK_QUEUE_H_
#define SRC_VM_TICK_QUEUE_H_

#include "src/shared/atomic.h"
#include "src/shared/globals.h"
#include "src/shared/platform.h"

namespace fletch {

class Process;

// TickSample captures the information collected for each profiler tick.
class TickSample {
 public:
  int  hashtag;  // hashtag from the running snapshot.
  int  bcp;  // bytecode pointer relative to heap start.
  word pc;
  word sp;
  word fp;
};

// Lock-free tick queue. Intended for transfer of tick records
// from the signal handler (producer) to the tick processor.
class TickQueue {
 public:
  TickQueue()
      : discarded_ticks_(0),
        add_pos_(Begin()),
        remove_pos_(Begin()) {}
  ~TickQueue() {}

  // Interface used by the producer.
  // If StartAdd returns non-NULL a CompleteAdd must follow.
  // NULL is returned if the queue is full.
  TickSample* StartAdd() {
    TickSample* remove_pos = remove_pos_;
    TickSample* next_add_pos = Next(add_pos_);
    if (next_add_pos == remove_pos) {
      discarded_ticks_++;  // Overflow of queue.
      return NULL;
    }
    return add_pos_;
  }

  void CompleteAdd() {
    add_pos_ = Next(add_pos_);
  }

  // Interface used by the consumer.
  // If StartRemove returns non-NULL a CompleteRemove must follow.
  // NULL is returned if the queue is empty.
  TickSample* StartRemove() {
    TickSample* ap = add_pos_;
    if (remove_pos_ == ap) return NULL;
    return remove_pos_;
  }

  void CompleteRemove() {
    remove_pos_ = Next(remove_pos_);
  }

  // Tells how many ticks have been discarded due to overflow.
  int DiscardedTicks() { return discarded_ticks_; }

  // Length of the array holding the queue elements.
  static const int kLength = 1024;
  // One element is always kept unused to distinguish empty from full.
  static const int kCapacity = kLength - 1;

 private:
  int discarded_ticks_;

  TickSample* Begin() { return &buffer_[0]; }
  TickSample* End() { return &buffer_[kLength]; }

  TickSample* Next(TickSample* entry) {
    TickSample* next = entry + 1;
    if (next == End()) return Begin();
    return next;
  }
  TickSample buffer_[kLength];
  Atomic<TickSample*> add_pos_;  // Only changed by producer.
  Atomic<TickSample*> remove_pos_;  // Only changed by consumer.
  DISALLOW_COPY_AND_ASSIGN(TickQueue);
};

}  // namespace fletch

#endif  // SRC_VM_TICK_QUEUE_H_
