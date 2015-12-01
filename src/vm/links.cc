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

  Signal* signal = NULL;

  HashSet<ProcessHandle*>::Iterator it = handles_.Begin();
  while (it != handles_.End()) {
    ProcessHandle* handle = *it;
    signal = SendSignal(handle, dying_handle, kind, signal);
    ProcessHandle::DecrementRef(handle);
    ++it;
  }
  handles_.Clear();
  half_dead_ = true;
  exit_kind_ = kind;

  if (signal != NULL) Signal::DecrementRef(signal);
}

void Links::NotifyMonitors(ProcessHandle* dying_handle) {
  ScopedSpinlock locker(&lock_);
  Signal* signal = NULL;
  ASSERT(half_dead_);
  for (HashSet<Port*>::Iterator it = ports_.Begin(); it != ports_.End(); ++it) {
    Port* port = *it;
    signal = EnqueueSignal(port, dying_handle, exit_kind_, signal);
    port->DecrementRef();
  }
  ports_.Clear();

  if (signal != NULL) Signal::DecrementRef(signal);
}

Signal* Links::EnqueueSignal(Port* port,
                             ProcessHandle* dying_handle,
                             Signal::Kind kind,
                             Signal* signal) {
  // We do this nested check for `port->process()` for two reasons:
  //    * avoid allocating [Signal] if we definitly do not need it
  //    * avoid allocating [Signal] while holding a [Spinlock]
  if (port->process() != NULL) {
    if (signal == NULL) signal = new Signal(dying_handle, kind);
    signal->IncrementRef();
    uword address = reinterpret_cast<uword>(signal);
    Message* message =
        new Message(port, address, 0, Message::PROCESS_DEATH_SIGNAL);

    {
      ScopedSpinlock locker(port->spinlock());
      Process* process = port->process();
      if (process != NULL) {
        process->mailbox()->EnqueueEntry(message);
        process->program()->scheduler()->ResumeProcess(process);
        message = NULL;
      }
    }

    if (message != NULL) delete message;
  }

  return signal;
}

Signal* Links::SendSignal(ProcessHandle* handle,
                          ProcessHandle* dying_handle,
                          Signal::Kind kind,
                          Signal* signal) {
  // We do this nested check for `handle->process()` for two reasons:
  //    * avoid allocating [Signal] if we definitly do not need it
  //    * avoid allocating [Signal] while holding a [Spinlock]
  if (handle->process() != NULL) {
    if (signal == NULL) signal = new Signal(dying_handle, kind);

    {
      ScopedSpinlock locker(handle->lock());
      Process* process = handle->process();
      if (process != NULL) {
        signal->IncrementRef();
        process->SendSignal(signal);
        process->program()->scheduler()->SignalProcess(process);
      }
    }
  }

  return signal;
}

}  // namespace fletch
