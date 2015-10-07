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

  auto it = timeouts_.Find(port);
  if (it == timeouts_.End()) {
    // If timeout is -1 but we can't find a previous one for the port, we have
    // already acted on it (but hasn't reached Dart yet). Simply ignore it.
    if (timeout == -1) return;
    timeouts_[port] = timeout;
    next_timeout_ = Utils::Minimum(next_timeout_, timeout);
    // Be sure to mark the port as referenced.
    port->IncrementRef();
  } else if (timeout == -1) {
    timeouts_.Erase(it);
    // TODO(ajohnsen): We could consider a heap structure to avoid O(n) in this
    // case?
    int64 next_timeout = INT64_MAX;
    for (auto it = timeouts_.Begin(); it != timeouts_.End(); ++it) {
      next_timeout = Utils::Minimum(next_timeout, it->second);
    }
    next_timeout_ = next_timeout;
    // The port is no longer "referenced" by the event manager.
    port->DecrementRef();
  } else {
    timeouts_[port] = timeout;
    next_timeout_ = Utils::Minimum(next_timeout_, timeout);
  }

  Interrupt();
}

void EventHandler::HandleTimeouts() {
  // Check timeouts.
  int64 current_time = Platform::GetMicroseconds() / 1000;

  ScopedMonitorLock scoped_lock(monitor_);
  if (next_timeout_ > current_time) return;

  int64 next_timeout = INT64_MAX;

  // TODO(ajohnsen): We could consider a heap structure to avoid O(n^2) in
  // this case?
  // The following is O(n^2), because we can't continue iterating a hash-map
  // once we have removed from it.
  while (true) {
    bool found = false;
    for (auto it = timeouts_.Begin(); it != timeouts_.End(); ++it) {
      if (it->second <= current_time) {
        Send(it->first, 0);
        timeouts_.Erase(it);
        found = true;
        break;
      } else {
        next_timeout = Utils::Minimum(next_timeout, it->second);
      }
    }
    if (!found) break;
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
