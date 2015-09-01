// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include "src/vm/event_handler.h"

#include <sys/epoll.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

#include "src/vm/thread.h"

// Some versions of android sys/epoll does not define
// EPOLLRDHUP. However, it works as intended, so we just
// define it if it is not there.
#if !defined(EPOLLRDHUP)
#define EPOLLRDHUP 0x2000
#endif  // !defined(EPOLLRDHUP)

namespace fletch {

int EventHandler::Create() {
  int fd = epoll_create(1);
  int status = fcntl(fd, F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making epoll descriptor close on exec.");
  return fd;
}

void EventHandler::Run() {
  struct epoll_event event;
  event.events = EPOLLHUP | EPOLLRDHUP;
  event.data.fd = read_fd_;
  epoll_ctl(fd_, EPOLL_CTL_ADD, read_fd_, &event);
  while (true) {
    int status = epoll_wait(fd_, &event, 1, -1);
    if (status != 1) continue;

    if (event.data.fd == read_fd_) {
      close(read_fd_);
      close(fd_);

      ScopedMonitorLock locker(monitor_);
      fd_ = -1;
      monitor_->Notify();
      return;
    }

    int events = event.events;
    word mask = 0;
    if ((events & EPOLLIN) != 0) mask |= READ_EVENT;
    if ((events & EPOLLOUT) != 0) mask |= WRITE_EVENT;
    if ((events & EPOLLRDHUP) != 0) mask |= CLOSE_EVENT;
    if ((events & EPOLLHUP) != 0) mask |= CLOSE_EVENT;
    if ((events & EPOLLERR) != 0) mask |= ERROR_EVENT;

    Port* port = reinterpret_cast<Port*>(event.data.ptr);
    Send(port, mask);
  }
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LINUX)
