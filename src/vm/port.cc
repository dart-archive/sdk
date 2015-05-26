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
      lock_(false),
      next_(process->ports()) {
  ASSERT(process != NULL);
  ASSERT(Thread::IsCurrent(process->thread_state()->thread()));
  process->set_ports(this);
}

Port::~Port() {
  ASSERT(ref_count_ == 0);
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

Port* Port::CleanupPorts(Port* head) {
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
      delete current;
    } else {
      if (current->channel_ != NULL) {
        HeapObject* forward = current->channel_->forwarding_address();
        current->channel_ = reinterpret_cast<Instance*>(forward);
      }
      previous = current;
    }
    current = next;
  }
#ifdef DEBUG
  current = head;
  while (current != NULL) {
    ASSERT(current->ref_count_ > 0);
    current = current->next();
  }
#endif
  return head;
}

void Port::WeakCallback(HeapObject* object) {
  Instance* instance = Instance::cast(object);
  ASSERT(instance->IsPort());
  Object* field = instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  Port* port = reinterpret_cast<Port*>(address);
  port->DecrementRef();
}

NATIVE(PortCreate) {
  Object* object = process->NewInteger(0);
  if (object == Failure::retry_after_gc()) return object;
  LargeInteger* value = LargeInteger::cast(object);
  Instance* channel = Instance::cast(arguments[0]);
  Instance* dart_port = Instance::cast(arguments[1]);
  Port* port = new Port(process, channel);
  process->RegisterFinalizer(dart_port, Port::WeakCallback);
  value->set_value(reinterpret_cast<uword>(port));
  return value;
}

NATIVE(PortClose) {
  word address = AsForeignWord(arguments[0]);
  Instance* dart_port = Instance::cast(arguments[1]);
  Port* port = reinterpret_cast<Port*>(address);
  process->UnregisterFinalizer(dart_port);
  port->DecrementRef();
  return process->program()->null_object();
}

NATIVE(PortSend) {
  Instance* instance = Instance::cast(arguments[0]);
  ASSERT(instance->IsPort());
  Object* field = instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  if (address == 0) return Failure::illegal_state();
  Port* port = reinterpret_cast<Port*>(address);
  port->Lock();
  Process* port_process = port->process();
  if (port_process != NULL) {
    Object* message = arguments[1];
    if (!port_process->Enqueue(port, message)) {
      port->Unlock();
      return Failure::wrong_argument_type();
    }
    // Return the locked port. This will allow the scheduler to
    // schedule the owner of the port, while it's still alive.
    return reinterpret_cast<Object*>(port);
  }
  port->Unlock();
  return process->program()->null_object();
}

NATIVE(PortSendExit) {
  Instance* instance = Instance::cast(arguments[0]);
  ASSERT(instance->IsPort());
  Object* field = instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  if (address == 0) return Failure::illegal_state();

  Port* port = reinterpret_cast<Port*>(address);
  port->Lock();

  Process* port_process = port->process();
  if (port_process != NULL && port_process != process) {
    Object* message = arguments[1];

    // If the result is a simple object, we can just enqueue it as such.
    if (!port_process->Enqueue(port, message)) {
      // Enqueue the exit message and return the locked port. This
      // will allow the scheduler to schedule the owner of the port,
      // while it's still alive.
      port_process->EnqueueExit(process, port, message);
    }

    return TargetYieldResult(port, true, false).AsObject();
  }

  port->Unlock();
  return Failure::illegal_state();
}

NATIVE(PortSendList) {
  Instance* instance = Instance::cast(arguments[0]);
  ASSERT(instance->IsPort());
  Object* field = instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  if (address == 0) return Failure::illegal_state();

  Instance* growable = Instance::cast(arguments[1]);
  Smi* length = Smi::cast(growable->GetInstanceField(0));
  Instance* fixed = Instance::cast(growable->GetInstanceField(1));
  Array* array = Array::cast(fixed->GetInstanceField(0));
  for (int i = 0; i < length->value(); i++) {
    if (!process->IsValidForEnqueue(array->get(i))) {
      return Failure::wrong_argument_type();
    }
  }

  // Get hold of the port and the associated process.
  Port* port = reinterpret_cast<Port*>(address);
  port->Lock();
  Process* port_process = port->process();
  if (port_process == NULL) {
    port->Unlock();
    return process->program()->null_object();
  }

  port_process->Enqueue(port, arguments[2]);  // Sentinel.
  port_process->Enqueue(port, length);
  for (int i = 0; i < length->value(); i++) {
    bool enqueued = port_process->Enqueue(port, array->get(i));
    ASSERT(enqueued);
  }

  // Return the locked port. This will allow the scheduler to
  // schedule the owner of the port, while it's still alive.
  return reinterpret_cast<Object*>(port);
}

NATIVE(SystemIncrementPortRef) {
  Instance* instance = Instance::cast(arguments[0]);
  ASSERT(instance->IsPort());
  Object* field = instance->GetInstanceField(0);
  uword address = AsForeignWord(field);
  Port* port = reinterpret_cast<Port*>(address);
  Object* result = process->ToInteger(address);
  if (result == Failure::retry_after_gc()) return result;
  port->IncrementRef();
  return result;
}

}  // namespace fletch
