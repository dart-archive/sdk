// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LK)

#include "src/vm/event_handler.h"

#include <kernel/event.h>

#include "src/shared/utils.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace fletch {

void EventHandler::Create() {
  ASSERT(data_ == NULL);
  event_t* event = new event_t;
  event_init(event, false, EVENT_FLAG_AUTOUNSIGNAL);
  id_ = -1;
  data_ = reinterpret_cast<void*>(event);
}

void EventHandler::Interrupt() {
  if (event_signal(reinterpret_cast<event_t*>(data_), false) != NO_ERROR) {
    FATAL("Failed to signal event in event handler");
  }
}

void EventHandler::Run() {
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

    event_wait_timeout(reinterpret_cast<event_t*>(data_), next_timeout);

    {
      ScopedMonitorLock scoped_lock(monitor_);

      if (!running_) {
        event_t* event = reinterpret_cast<event_t*>(data_);
        event_destroy(event);
        delete event;
        data_ = NULL;
        monitor_->Notify();
        return;
      }
    }

    HandleTimeouts();
  }
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LK)
