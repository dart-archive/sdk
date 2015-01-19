// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/event_handler.h"

#include <sys/epoll.h>
#include <sys/types.h>
#include <unistd.h>

#include "src/vm/thread.h"

namespace fletch {

int EventHandler::Create() {
  return epoll_create(1);
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
      monitor_->Lock();
      fd_ = -1;
      monitor_->Notify();
      monitor_->Unlock();
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
