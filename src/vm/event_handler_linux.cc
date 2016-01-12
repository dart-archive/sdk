// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include "src/vm/event_handler.h"

#include <sys/epoll.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

#include "src/shared/utils.h"
#include "src/vm/thread.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

// Some versions of android sys/epoll does not define
// EPOLLRDHUP. However, it works as intended, so we just
// define it if it is not there.
#if !defined(EPOLLRDHUP)
#define EPOLLRDHUP 0x2000
#endif  // !defined(EPOLLRDHUP)

namespace fletch {

void EventHandler::Create() {
  int* fds = new int[2];
  if (pipe(fds) != 0) FATAL("Failed to start the event handler pipe\n");
  int status = fcntl(fds[0], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making read pipe close on exec.");
  status = fcntl(fds[1], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making write pipe close on exec.");

  id_ = epoll_create(1);
  if (id_ == -1) FATAL("Failed creating epoll instance.");
  status = fcntl(id_, F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making epoll descriptor close on exec.");

  struct epoll_event event;
  event.events = EPOLLHUP | EPOLLRDHUP | EPOLLIN;
  event.data.fd = fds[0];
  epoll_ctl(id_, EPOLL_CTL_ADD, fds[0], &event);

  data_ = reinterpret_cast<void*>(fds);
}

void EventHandler::Run() {
  int* fds = reinterpret_cast<int*>(data_);

  while (true) {
    int64 next_timeout;
    {
      ScopedMonitorLock locker(monitor_);
      next_timeout = next_timeout_;
    }

    if (next_timeout == INT64_MAX) {
      next_timeout = -1;
    } else {
      next_timeout -= Platform::GetMicroseconds() / 1000;
      if (next_timeout < 0) next_timeout = 0;
    }

    struct epoll_event event;
    int status = epoll_wait(id_, &event, 1, next_timeout);

    HandleTimeouts();

    if (status != 1) continue;

    int events = event.events;

    if (event.data.fd == fds[0]) {
      if (!running_) {
        ScopedMonitorLock locker(monitor_);
        close(id_);
        close(fds[0]);
        close(fds[1]);
        delete[] fds;
        data_ = NULL;
        monitor_->Notify();
        return;
      }

      char b;
      TEMP_FAILURE_RETRY(read(fds[0], &b, 1));
      continue;
    }

    int64 mask = 0;
    if ((events & EPOLLIN) != 0) mask |= READ_EVENT;
    if ((events & EPOLLOUT) != 0) mask |= WRITE_EVENT;
    if ((events & EPOLLRDHUP) != 0) mask |= CLOSE_EVENT;
    if ((events & EPOLLHUP) != 0) mask |= CLOSE_EVENT;
    if ((events & EPOLLERR) != 0) mask |= ERROR_EVENT;

    Port* port = reinterpret_cast<Port*>(event.data.ptr);
    Send(port, mask, true);
  }
}

Object* EventHandler::Add(Process* process, Object* id, Port* port,
                          int flags) {
  EnsureInitialized();

  int fd;
  if (id->IsSmi()) {
    fd = Smi::cast(id)->value();
  } else if (id->IsLargeInteger()) {
    fd = LargeInteger::cast(id)->value();
  } else {
    return Failure::wrong_argument_type();
  }

  struct epoll_event event;
  event.events = EPOLLRDHUP | EPOLLHUP | EPOLLONESHOT;
  if ((flags & ~(READ_EVENT | WRITE_EVENT)) != 0) {
    return Failure::illegal_state();
  }
  if ((flags & READ_EVENT) != 0) event.events |= EPOLLIN;
  if ((flags & WRITE_EVENT) != 0) event.events |= EPOLLOUT;
  event.data.ptr = port;
  int result = epoll_ctl(id_, EPOLL_CTL_MOD, fd, &event);
  if (result == -1 && errno == ENOENT) {
    // This is the first time we register the fd, so use ADD.
    result = epoll_ctl(id_, EPOLL_CTL_ADD, fd, &event);
  }
  if (result == -1) return Failure::index_out_of_bounds();
  // Only if the call to epoll_ctl succeeded do we actually have a reference to
  // the port.
  port->IncrementRef();
  return process->program()->null_object();
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LINUX)
