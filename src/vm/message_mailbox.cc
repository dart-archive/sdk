// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/message_mailbox.h"
#include "src/vm/process.h"

namespace dartino {

ExitReference::ExitReference(Object* message) : message_(message) {}

Message::~Message() {
  port_->DecrementRef();
  if (kind() == EXIT) {
    ExitReference* ref = reinterpret_cast<ExitReference*>(value());
    delete ref;
  } else if (kind() == PROCESS_DEATH_SIGNAL) {
    Signal* signal = reinterpret_cast<Signal*>(value());
    Signal::DecrementRef(signal);
  }
}

Message* Message::NewImmutableMessage(Port* port, Object* message) {
  if (!message->IsHeapObject()) {
    uint64 address = reinterpret_cast<uint64>(message);
    return new Message(port, address, 0, Message::IMMEDIATE);
  } else if (message->IsImmutable()) {
    uint64 address = reinterpret_cast<uint64>(message);
    return new Message(port, address, 0, Message::IMMUTABLE_OBJECT);
  }
  UNREACHABLE();
  return NULL;
}

void MessageMailbox::Enqueue(Port* port, Object* message) {
  EnqueueEntry(Message::NewImmutableMessage(port, message));
}

void MessageMailbox::EnqueueLargeInteger(Port* port, int64 value) {
  EnqueueEntry(new Message(port, value, 0, Message::LARGE_INTEGER));
}

void MessageMailbox::EnqueueForeign(Port* port, void* foreign, int size,
                                    bool finalized) {
  Message::Kind kind =
      finalized ? Message::FOREIGN_FINALIZED : Message::FOREIGN;
  uint64 address = reinterpret_cast<uint64>(foreign);
  Message* entry = new Message(port, address, size, kind);
  EnqueueEntry(entry);
}

void MessageMailbox::EnqueueExit(Process* sender, Port* port, Object* message) {
  uint64 address = reinterpret_cast<uint64>(message);
  Message* entry = new Message(port, address, 0, Message::IMMUTABLE_OBJECT);
  EnqueueEntry(entry);
}

}  // namespace dartino
