// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_MESSAGE_MAILBOX_H_
#define SRC_VM_MESSAGE_MAILBOX_H_

#include "src/shared/globals.h"
#include "src/shared/atomic.h"

#include "src/vm/heap.h"
#include "src/vm/mailbox.h"
#include "src/vm/port.h"
#include "src/vm/storebuffer.h"

namespace fletch {

class Process;

class ExitReference {
 public:
  ExitReference(Process* exiting_process, Object* message);

  Object* message() const { return message_; }

  void VisitPointers(PointerVisitor* visitor) {
    visitor->Visit(&message_);
  }

  Heap* mutable_heap() { return &mutable_heap_; }

  StoreBuffer* store_buffer() { return &store_buffer_; }

 private:
  Heap mutable_heap_;
  StoreBuffer store_buffer_;
  Object* message_;
};

class Message : public MailboxMessage<Message> {
 public:
  enum Kind {
    IMMEDIATE,
    IMMUTABLE_OBJECT,
    FOREIGN,
    FOREIGN_FINALIZED,
    EXIT
  };

  Message(Port* port, uword value, int size, Kind kind)
      : port_(port),
        value_(value),
        kind_and_size_(KindField::encode(kind) | SizeField::encode(size)) {
    port_->IncrementRef();
  }

  ~Message();

  static Message* NewImmutableMessage(Port* port, Object* message);

  Port* port() const { return port_; }
  uword address() const { return value_; }
  int size() const { return SizeField::decode(kind_and_size_); }
  Kind kind() const { return KindField::decode(kind_and_size_); }

  Object* ExitReferenceObject() {
    ASSERT(kind() == Message::EXIT);
    return reinterpret_cast<ExitReference*>(address())->message();
  }

  void VisitPointers(PointerVisitor* visitor) {
    switch (kind()) {
      case IMMUTABLE_OBJECT:
        visitor->Visit(reinterpret_cast<Object**>(&value_));
        break;
      case EXIT: {
        ExitReference* ref = reinterpret_cast<ExitReference*>(address());
        ref->VisitPointers(visitor);
        break;
      }
      default:
        break;
    }
  }

  void MergeChildHeaps(Process* destination_process);

 private:
  Port* port_;
  uword value_;
  class KindField: public BitField<Kind, 0, 3> { };
  class SizeField: public BitField<int, 3, 32 - 3> { };
  const int32 kind_and_size_;
};

class MessageMailbox : public Mailbox<Message> {
 public:
  void Enqueue(Port* port, Object* message);
  void EnqueueForeign(Port* port, void* foreign, int size, bool finalized);
  void EnqueueExit(Process* sender, Port* port, Object* message);

  void MergeAllChildHeaps(Process* destination_process);

 private:
  void MergeAllChildHeapsFromQueue(Message* queue,
                                   Process* destination_process);
};

}  // namespace fletch


#endif  // SRC_VM_MESSAGE_MAILBOX_H_
