// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/event_handler.h"

#include <fcntl.h>
#include <unistd.h>

#include "src/shared/flags.h"

#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace fletch {

EventHandler::EventHandler()
    : monitor_(Platform::CreateMonitor()),
      fd_(-1),
      next_timeout_(INT64_MAX),
      read_fd_(-1),
      write_fd_(-1) {
}

EventHandler::~EventHandler() {
  if (fd_ != -1) {
    // TODO(runtime-developers): This is pretty nasty, inside the destructor we
    // notify the other thread (via close()) to shut down. The other thread will
    // then access members of the [EventHandler] object which is in the middle
    // of destruction.
    ScopedMonitorLock locker(monitor_);
    close(write_fd_);
    while (fd_ != -1) monitor_->Wait();
    thread_.Join();
  }

  delete monitor_;
}

void* RunEventHandler(void* peer) {
  EventHandler* event_handler = reinterpret_cast<EventHandler*>(peer);
  event_handler->Run();
  return NULL;
}

int EventHandler::GetEventHandler() {
  ScopedMonitorLock locker(monitor_);

  if (fd_ >= 0) {
    return fd_;
  }
  fd_ = Create();
  if (fd_ < 0) FATAL("Failed to start event handler\n");

  int fds[2];
  if (pipe(fds) != 0) FATAL("Failed to start the event handler pipe\n");
  int status = fcntl(fds[0], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making read pipe close on exec.");
  status = fcntl(fds[1], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making write pipe close on exec.");
  read_fd_ = fds[0];
  write_fd_ = fds[1];
  thread_ = Thread::Run(RunEventHandler, reinterpret_cast<void*>(this));
  return fd_;
}

void EventHandler::ScheduleTimeout(int64 timeout, Port* port) {
  ASSERT(timeout != INT64_MAX);

  // Be sure it's running.
  GetEventHandler();

  ScopedMonitorLock scoped_lock(monitor_);

  auto it = timeouts_.Find(port);
  if (it == timeouts_.End()) {
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
  char b = 0;
  TEMP_FAILURE_RETRY(write(write_fd_, &b, 1));
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

#endif  // FLETCH_TARGET_OS_POSIX
