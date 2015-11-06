// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/links.h"

#include "src/vm/process.h"
#include "src/vm/program.h"
#include "src/vm/scheduler.h"

namespace fletch {

void Links::InsertPort(Port* port) {
  ScopedSpinlock locker(&lock_);
  if (objects_.Insert(MarkPort(port)).second) {
    port->IncrementRef();
  }
}

void Links::InsertHandle(ProcessHandle* handle) {
  ScopedSpinlock locker(&lock_);
  if (objects_.Insert(MarkHandle(handle)).second) {
    handle->IncrementRef();
  }
}

void Links::RemovePort(Port* port) {
  ScopedSpinlock locker(&lock_);
  HashSet<PortOrHandle>::ConstIterator it = objects_.Find(MarkPort(port));
  if (it != objects_.End()) {
    objects_.Erase(it);
    port->DecrementRef();
  }
}

void Links::RemoveHandle(ProcessHandle* handle) {
  ScopedSpinlock locker(&lock_);
  HashSet<PortOrHandle>::ConstIterator it = objects_.Find(MarkHandle(handle));
  if (it != objects_.End()) {
    objects_.Erase(it);
    ProcessHandle::DecrementRef(handle);
  }
}

void Links::CleanupWithSignal(ProcessHandle* dying_handle, Signal::Kind kind) {
  ScopedSpinlock locker(&lock_);
  for (HashSet<PortOrHandle>::Iterator it = objects_.Begin();
       it != objects_.End();
       ++it) {
    PortOrHandle object = *it;
    if (IsPort(object)) {
      Port* port = UnmarkPort(object);
      EnqueueSignal(port, kind);
      port->DecrementRef();
    } else {
      ProcessHandle* handle = UnmarkHandle(object);
      SendSignal(handle, dying_handle, kind);
      ProcessHandle::DecrementRef(handle);
    }
  }
  objects_.Clear();
}

void Links::EnqueueSignal(Port* port, Signal::Kind kind) {
  // We do this nested check for `port->process()` for two reasons:
  //    * avoid allocating [Signal] if we definitly do not need it
  //    * avoid allocating [Signal] while holding a [Spinlock]
  if (port->process() != NULL) {
    uword address = reinterpret_cast<uword>(Smi::FromWord(kind));
    Message* message = new Message(port, address, 0, Message::IMMEDIATE);

    {
      port->Lock();
      Process* process = port->process();
      if (process != NULL) {
        process->mailbox()->EnqueueEntry(message);
        process->program()->scheduler()->ResumeProcess(process);
        message = NULL;
      }
      port->Unlock();
    }

    if (message != NULL) delete message;
  }
}

void Links::SendSignal(ProcessHandle* handle,
                       ProcessHandle* dying_handle,
                       Signal::Kind kind) {
  // Everything that was not a normal termination will trigger a signal.
  if (kind != Signal::kTerminated) {
    // We do this nested check for `handle->process()` for two reasons:
    //    * avoid allocating [Signal] if we definitly do not need it
    //    * avoid allocating [Signal] while holding a [Spinlock]

    if (handle->process() != NULL) {
      Signal* signal = new Signal(dying_handle, kind);

      {
        ScopedSpinlock locker(handle->lock());
        Process* process = handle->process();
        if (process != NULL) {
          process->signal_mailbox()->EnqueueEntry(signal);
          process->program()->scheduler()->SignalProcess(process);
          signal = NULL;
        }
      }

      if (signal != NULL) delete signal;
    }
  }
}

}  // namespace fletch
