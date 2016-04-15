// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_MACOS)

#include "src/vm/event_handler.h"

#include <fcntl.h>
#include <sys/event.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/thread.h"

namespace dartino {

void EventHandler::Create() {
  int* fds = new int[2];
  if (pipe(fds) != 0) FATAL("Failed to start the event handler pipe\n");
  int status = fcntl(fds[0], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making read pipe close on exec.");
  status = fcntl(fds[1], F_SETFD, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making write pipe close on exec.");

  id_ = kqueue();
  if (id_ == -1) FATAL("Failed creating kqueue instance.");

  struct kevent event = {};
  event.ident = fds[0];
  event.flags = EV_ADD;
  event.filter = EVFILT_READ;
  kevent(id_, &event, 1, NULL, 0, NULL);

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

    timespec ts;
    timespec* interval = NULL;

    if (next_timeout != INT64_MAX) {
      next_timeout -= Platform::GetMicroseconds() / 1000;
      if (next_timeout < 0) next_timeout = 0;
      ts.tv_sec = next_timeout / 1000;
      ts.tv_nsec = (next_timeout % 1000) * 1000000;
      interval = &ts;
    }

    struct kevent event;
    int status = kevent(id_, NULL, 0, &event, 1, interval);

    HandleTimeouts();

    if (status != 1) continue;

    int filter = event.filter;
    int flags = event.flags;
    int fflags = event.fflags;

    if (event.ident == static_cast<uintptr_t>(fds[0])) {
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
    if (filter == EVFILT_READ) {
      mask = READ_EVENT;
      if ((flags & EV_EOF) != 0) {
        if (fflags != 0) {
          mask = ERROR_EVENT;
        } else {
          mask |= CLOSE_EVENT;
        }
      }
    } else if (filter == EVFILT_WRITE) {
      if ((flags & EV_EOF) != 0 && fflags != 0) {
        mask = ERROR_EVENT;
      } else {
        mask = WRITE_EVENT;
      }
    }

    EventListener* event_listener =
        reinterpret_cast<EventListener*>(event.udata);

    event_listener->Send(mask);
  }
}

EventHandler::Status EventHandler::AddEventListener(
    Object* id, EventListener* event_listener, int flags) {
  EnsureInitialized();

  int fd;
  if (id->IsSmi()) {
    fd = Smi::cast(id)->value();
  } else if (id->IsLargeInteger()) {
    fd = LargeInteger::cast(id)->value();
  } else {
    delete event_listener;
    return Status::WRONG_ARGUMENT_TYPE;
  }

  struct kevent event = {};
  event.ident = fd;
  event.flags = EV_ADD | EV_ONESHOT;
  event.udata = event_listener;
  if (flags == READ_EVENT) {
    event.filter = EVFILT_READ;
  } else if (flags == WRITE_EVENT) {
    event.filter = EVFILT_WRITE;
  } else {
    delete event_listener;
    Print::Error("Listening for both READ_EVENT and WRITE_EVENT is currently"
                 " unsupported on mac os.");
    return Status::ILLEGAL_STATE;
  }
  int result = kevent(id_, &event, 1, NULL, 0, NULL);
  if (result == -1) {
    delete event_listener;
    return Status::INDEX_OUT_OF_BOUNDS;
  }
  return Status::OK;
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_MACOS)
