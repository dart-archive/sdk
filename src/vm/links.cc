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
  if (ports_.Insert(port).second) {
    port->IncrementRef();
  }
}

bool Links::InsertHandle(ProcessHandle* handle) {
  ScopedSpinlock locker(&lock_);
  if (half_dead_) return false;
  if (handles_.Insert(handle).second) {
    handle->IncrementRef();
  }
  return true;
}

void Links::RemovePort(Port* port) {
  ScopedSpinlock locker(&lock_);
  HashSet<Port*>::ConstIterator it = ports_.Find(port);
  if (it != ports_.End()) {
    ports_.Erase(it);
    port->DecrementRef();
  }
}

void Links::RemoveHandle(ProcessHandle* handle) {
  ScopedSpinlock locker(&lock_);
  HashSet<ProcessHandle*>::ConstIterator it = handles_.Find(handle);
  if (it != handles_.End()) {
    handles_.Erase(it);
    ProcessHandle::DecrementRef(handle);
  }
}

void Links::NotifyLinkedProcesses(ProcessHandle* dying_handle,
                                  Signal::Kind kind) {
  ScopedSpinlock locker(&lock_);
  ASSERT(!half_dead_);

  HashSet<ProcessHandle*>::Iterator it = handles_.Begin();
  while (it != handles_.End()) {
    ProcessHandle* handle = *it;
    SendSignal(handle, dying_handle, kind);
    ProcessHandle::DecrementRef(handle);
    ++it;
  }
  handles_.Clear();
  half_dead_ = true;
  exit_kind_ = kind;
}

void Links::NotifyMonitors(ProcessHandle* dying_handle) {
  ScopedSpinlock locker(&lock_);
  ASSERT(half_dead_);
  for (HashSet<Port*>::Iterator it = ports_.Begin(); it != ports_.End(); ++it) {
    Port* port = *it;
    EnqueueSignal(port, exit_kind_);
    port->DecrementRef();
  }
  ports_.Clear();
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

}  // namespace fletch
