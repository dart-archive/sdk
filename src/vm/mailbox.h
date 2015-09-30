// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_MAILBOX_H_
#define SRC_VM_MAILBOX_H_

#include "src/shared/globals.h"
#include "src/shared/atomic.h"

#include "src/vm/object.h"

namespace fletch {

template<typename MessageType>
class Mailbox {
 public:
  Mailbox() : last_message_(NULL), current_message_(NULL) {}
  ~Mailbox() {
    while (last_message_ != NULL) {
      MessageType* entry = last_message_;
      last_message_ = entry->next();
      delete entry;
    }
    while (current_message_ != NULL) {
      MessageType* entry = current_message_;
      current_message_ = entry->next();
      delete entry;
    }
    ASSERT(last_message_ == NULL);
  }

  void EnqueueEntry(MessageType* entry) {
    ASSERT(entry->next() == NULL);
    MessageType* last = last_message_;
    while (true) {
      entry->set_next(last);
      if (last_message_.compare_exchange_weak(last, entry)) break;
    }
  }

  // Thread-safe way of asking if the mailbox is empty.
  bool IsEmpty() const { return last_message_ == NULL; }

  void TakeQueue() {
    ASSERT(current_message_ == NULL);
    MessageType* last = last_message_;
    while (!last_message_.compare_exchange_weak(last, NULL)) { }
    current_message_ = Reverse(last);
  }

  MessageType* CurrentMessage() {
    if (current_message_ == NULL) TakeQueue();
    return current_message_;
  }

  void AdvanceCurrentMessage() {
    ASSERT(current_message_ != NULL);
    MessageType* temp = current_message_;
    current_message_ = current_message_->next();
    delete temp;
  }

  void IteratePointers(PointerVisitor* visitor) {
    IterateMailQueuePointers(last_message_, visitor);
    IterateMailQueuePointers(current_message_, visitor);
  }

 protected:
  // Pointer to the last [MessageType] element which is concurrently modified
  // using atomics.
  Atomic<MessageType*> last_message_;

  // Process-local list of [MessageType] elements currently being processed.
  MessageType* current_message_;

 private:
  void IterateMailQueuePointers(MessageType* entry, PointerVisitor* visitor) {
    for (MessageType* current = entry;
         current != NULL;
         current = current->next()) {
       current->VisitPointers(visitor);
    }
  }

  MessageType* Reverse(MessageType* queue) {
    MessageType* previous = NULL;
    while (queue != NULL) {
      MessageType* next = queue->next();
      queue->set_next(previous);
      previous = queue;
      queue = next;
    }
    return previous;
  }
};

template<typename MessageType>
class MailboxMessage {
 public:
  MailboxMessage() : next_(NULL) {}

  MessageType* next() const { return next_; }
  void set_next(MessageType* next) { next_ = next; }

 private:
  MessageType* next_;
};

}  // namespace fletch


#endif  // SRC_VM_MAILBOX_H_
