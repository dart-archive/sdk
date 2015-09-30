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
