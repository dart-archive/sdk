// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_MESSAGE_MAILBOX_H_
#define SRC_VM_MESSAGE_MAILBOX_H_

#include "src/shared/globals.h"
#include "src/shared/atomic.h"

#include "src/vm/heap.h"
#include "src/vm/mailbox.h"
#include "src/vm/port.h"

namespace dartino {

class Process;
class Signal;

class ExitReference {
 public:
  explicit ExitReference(Object* message);

  Object* message() const { return message_; }

  void VisitPointers(PointerVisitor* visitor) { visitor->Visit(&message_); }

 private:
  Object* message_;
};

class Message : public MailboxMessage<Message> {
 public:
  enum Kind {
    IMMEDIATE,
    IMMUTABLE_OBJECT,
    LARGE_INTEGER,
    FOREIGN,
    FOREIGN_FINALIZED,
    PROCESS_DEATH_SIGNAL,
    EXIT,
  };

  Message(Port* port, uint64 value, int size, Kind kind)
      : port_(port),
        value_(value),
        kind_and_size_(KindField::encode(kind) | SizeField::encode(size)) {
    port_->IncrementRef();
  }

  ~Message();

  static Message* NewImmutableMessage(Port* port, Object* message);

  Port* port() const { return port_; }
  uint64 value() const { return value_; }
  int size() const { return SizeField::decode(kind_and_size_); }
  Kind kind() const { return KindField::decode(kind_and_size_); }

  Object* ExitReferenceObject() {
    ASSERT(kind() == Message::EXIT);
    return reinterpret_cast<ExitReference*>(value())->message();
  }

  Signal* ProcessDeathSignal() {
    ASSERT(kind() == Message::PROCESS_DEATH_SIGNAL);
    return reinterpret_cast<Signal*>(value());
  }

  void VisitPointers(PointerVisitor* visitor) {
    switch (kind()) {
      case IMMUTABLE_OBJECT:
        visitor->Visit(reinterpret_cast<Object**>(&value_));
        break;
      case EXIT: {
        ExitReference* ref = reinterpret_cast<ExitReference*>(value());
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
  uint64 value_;
  class KindField : public BitField<Kind, 0, 3> {};
  class SizeField : public BitField<int, 3, 32 - 3> {};
  const int32 kind_and_size_;
};

class MessageMailbox : public Mailbox<Message> {
 public:
  void Enqueue(Port* port, Object* message);
  void EnqueueLargeInteger(Port* port, int64 value);
  void EnqueueForeign(Port* port, void* foreign, int size, bool finalized);
  void EnqueueExit(Process* sender, Port* port, Object* message);

  void MergeAllChildHeaps(Process* destination_process);

 private:
  void MergeAllChildHeapsFromQueue(Message* queue,
                                   Process* destination_process);
};

}  // namespace dartino

#endif  // SRC_VM_MESSAGE_MAILBOX_H_
