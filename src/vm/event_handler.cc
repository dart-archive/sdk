// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/event_handler.h"

#include "src/shared/utils.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace fletch {

EventHandler::EventHandler()
    : monitor_(Platform::CreateMonitor()),
      data_(NULL),
      id_(-1),
      running_(true),
      next_timeout_(INT64_MAX) {
}

EventHandler::~EventHandler() {
  if (data_ != NULL) {
    ScopedMonitorLock locker(monitor_);
    running_ = false;
    Interrupt();
    while (data_ != NULL) monitor_->Wait();
    thread_.Join();
  }

  delete monitor_;
}

void* EventHandler::RunEventHandler(void* peer) {
  EventHandler* event_handler = reinterpret_cast<EventHandler*>(peer);
  event_handler->Run();
  return NULL;
}

int EventHandler::GetEventHandler() {
  ScopedMonitorLock locker(monitor_);

  if (data_ == NULL) {
    Create();
    thread_ = Thread::Run(RunEventHandler, reinterpret_cast<void*>(this));
  }

  return id_;
}

void EventHandler::ScheduleTimeout(int64 timeout, Port* port) {
  ASSERT(timeout != INT64_MAX);

  // Be sure it's running.
  GetEventHandler();

  ScopedMonitorLock scoped_lock(monitor_);

  if (timeout == -1) {
    if (timeouts_.RemoveByValue(port)) {
      port->DecrementRef();
    } else {
      // If timeout is -1 but we can't find a previous one for the port, we have
      // already acted on it (but hasn't reached Dart yet). Simply ignore it.
      return;
    }
  } else {
    if (timeouts_.InsertOrChangePriority(timeout, port)) {
      port->IncrementRef();
    }
  }

  next_timeout_ =
      timeouts_.IsEmpty() ? INT64_MAX : timeouts_.Minimum().priority;

  Interrupt();
}

void EventHandler::HandleTimeouts() {
  // Check timeouts.
  int64 current_time = Platform::GetMicroseconds() / 1000;

  ScopedMonitorLock scoped_lock(monitor_);
  if (next_timeout_ > current_time) return;

  int64 next_timeout = INT64_MAX;
  while (!timeouts_.IsEmpty()) {
    auto minimum = timeouts_.Minimum();
    if (minimum.priority <= current_time) {
      Send(minimum.value, 0);
      timeouts_.RemoveMinimum();
    } else {
      next_timeout = minimum.priority;
      break;
    }
  }
  next_timeout_ = next_timeout;
}

void EventHandler::Send(Port* port, uword mask) {
  Object* message = Smi::FromWord(mask);
  port->Lock();
  Process* port_process = port->process();
  if (port_process != NULL) {
    port_process->mailbox()->Enqueue(port, message);
    port_process->program()->scheduler()->ResumeProcess(port_process);
  }
  port->Unlock();
  port->DecrementRef();
}

}  // namespace fletch
