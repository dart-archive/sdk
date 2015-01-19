// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/event_handler.h"

#include <unistd.h>

#include "src/shared/flags.h"

#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/thread.h"

namespace fletch {

EventHandler::EventHandler()
    : fd_(-1),
      read_fd_(-1),
      write_fd_(-1),
      monitor_(Platform::CreateMonitor()) {
}

EventHandler::~EventHandler() {
  if (fd_ != -1) {
    monitor_->Lock();
    close(write_fd_);
    while (fd_ != -1) monitor_->Wait();
    monitor_->Unlock();
  }

  delete monitor_;
}

void* RunEventHandler(void* peer) {
  EventHandler* event_handler = reinterpret_cast<EventHandler*>(peer);
  event_handler->Run();
  return NULL;
}

int EventHandler::GetEventHandler() {
  monitor_->Lock();
  if (fd_ >= 0) {
    monitor_->Unlock();
    return fd_;
  }
  fd_ = Create();
  monitor_->Unlock();
  int fds[2];
  if (pipe(fds) != 0) FATAL("Failed to start the event handler pipe\n");
  read_fd_ = fds[0];
  write_fd_ = fds[1];
  Thread::Run(RunEventHandler, reinterpret_cast<void*>(this));
  return fd_;
}

void EventHandler::Send(Port* port, uword mask) {
  Object* message = Smi::FromWord(mask);
  port->Lock();
  Process* port_process = port->process();
  if (port_process != NULL) {
    bool enqueued = port_process->Enqueue(port, message);
    ASSERT(enqueued);
    port_process->program()->scheduler()->ResumeProcess(port_process);
  }
  port->Unlock();
  port->DecrementRef();
}

}  // namespace fletch
