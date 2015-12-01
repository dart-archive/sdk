// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/port.h"

#include <stdlib.h>

#include "src/vm/interpreter.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

Port::Port(Process* process, Instance* channel)
    : process_(process),
      channel_(channel),
      ref_count_(1),
      spinlock_(),
      next_(process->ports()) {
  ASSERT(process != NULL);
  ASSERT(Thread::IsCurrent(process->thread_state()->thread()));
  process->set_ports(this);
}

Port::~Port() {
  ASSERT(ref_count_ == 0);
}

Port* Port::FromDartObject(Object* dart_port) {
  ASSERT(dart_port->IsPort());
  Object* p = Instance::cast(dart_port)->GetInstanceField(0);
  uword address = Smi::cast(p)->value() << 2;
  return reinterpret_cast<Port*>(address);
}

void Port::IncrementRef() {
  ASSERT(ref_count_ > 0);
  ref_count_++;
}

void Port::DecrementRef() {
  Lock();
  ASSERT(ref_count_ > 0);
  if (--ref_count_ == 0) {
    // If the owning process is gone, delete the port now. Otherwise, leave
    // the deletion of the port to the process so it can remove the port from
    // the list of ports.
    if (process() == NULL) {
      delete this;
      return;
    }
  }
  Unlock();
}

void Port::OwnerProcessTerminating() {
  Lock();
  if (ref_count_ == 0) {
    delete this;
    return;
  } else {
    set_process(NULL);
  }
  Unlock();
}

Port* Port::CleanupPorts(Space* space, Port* head) {
  Port* current = head;
  Port* previous = NULL;
  while (current != NULL) {
    Port* next = current->next();
    if (current->ref_count_ == 0) {
      if (previous == NULL) {
        head = next;
      } else {
        previous->set_next(next);
      }
      current->channel_ = reinterpret_cast<Instance*>(0xcafecafe);
      delete current;
    } else {
      HeapObject* channel = current->channel_;
      if (channel != NULL && space->Includes(channel->address())) {
#ifdef FLETCH_MARK_SWEEP
        if (!channel->IsMarked()) current->channel_ = NULL;
#else
        // If the channel is not reachable the forwarding_address will
        // be NULL. Therefore, we should always update the channel with
        // the forwarding address.
        HeapObject* forward = channel->forwarding_address();
        current->channel_ = reinterpret_cast<Instance*>(forward);
#endif
      }
      previous = current;
    }
    current = next;
  }
  return head;
}

void Port::WeakCallback(HeapObject* object, Heap* heap) {
  Port* port = Port::FromDartObject(object);
  port->DecrementRef();
}

NATIVE(PortCreate) {
  Instance* channel = Instance::cast(arguments[0]);

  Object* dart_port =
      process->NewInstance(process->program()->port_class(), true);
  if (dart_port == Failure::retry_after_gc()) return dart_port;
  Instance* port_instance = Instance::cast(dart_port);

  Port* port = new Port(process, channel);
  ASSERT((reinterpret_cast<uword>(port) & 3) == 0);  // Always aligned.
  Smi* p = Smi::FromWord(reinterpret_cast<uword>(port) >> 2);
  port_instance->SetInstanceField(0, p);
  process->RegisterFinalizer(port_instance, Port::WeakCallback);

  return port_instance;
}

NATIVE(PortSend) {
  Instance* instance = Instance::cast(arguments[0]);

  Object* message = arguments[1];
  if (!message->IsImmutable()) return Failure::wrong_argument_type();

  Port* port = Port::FromDartObject(instance);
  if (port == NULL) return Failure::illegal_state();

  // We want to avoid holding a spinlock while doing an allocation, so:
  //    * we do an early return if the destination process is not there
  //    * we allocate (and possibly free) the message outside of the spinlock
  //      region.
  if (port->process() != NULL) {
    Message* entry = Message::NewImmutableMessage(port, message);

    port->Lock();
    Process* port_process = port->process();
    if (port_process != NULL) {
      port_process->mailbox()->EnqueueEntry(entry);
      entry = NULL;

      if (port_process != process) {
        // If sending to another process, return the locked port. This will
        // allow the scheduler to schedule the owner of the port, while it's
        // still alive.
        return reinterpret_cast<Object*>(port);
      }
    }
    port->Unlock();

    if (entry != NULL) delete entry;
  }
  return process->program()->null_object();
}

NATIVE(PortSendExit) {
  Instance* instance = Instance::cast(arguments[0]);
  Port* port = Port::FromDartObject(instance);
  if (port == NULL) return Failure::illegal_state();

  port->Lock();

  Process* port_process = port->process();
  if (port_process != NULL && port_process != process) {
    Object* message = arguments[1];

    // Enqueue the exit message and return the locked port. This
    // will allow the scheduler to schedule the owner of the port,
    // while it's still alive.
    if (message->IsImmutable()) {
      port_process->mailbox()->Enqueue(port, message);
    } else {
      port_process->mailbox()->EnqueueExit(process, port, message);
    }

    return TargetYieldResult(port, true).AsObject();
  }

  port->Unlock();
  return Failure::illegal_state();
}

NATIVE(SystemIncrementPortRef) {
  Port* port = Port::FromDartObject(arguments[0]);
  Object* result = process->ToInteger(reinterpret_cast<uword>(port));
  if (result == Failure::retry_after_gc()) return result;
  port->IncrementRef();
  return result;
}

}  // namespace fletch
