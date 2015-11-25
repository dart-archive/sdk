// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LK)

#include "src/vm/event_handler.h"

#include <kernel/event.h>
#include <kernel/port.h>

#include "src/shared/utils.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace fletch {

const char* kFletchInterruptPortName = "FLETCH_INT";

class PortSet {
 public:
  PortSet() : group(0), port_set(NULL) {
    // Init the port subsystem.
    port_init();

    // Create and add the interrupt port.
    port_create(kFletchInterruptPortName, PORT_MODE_UNICAST, &interrupt_port);
    port_t interrupt_read;
    port_open(kFletchInterruptPortName, NULL, &interrupt_read);
    AddReadPort(interrupt_read);
  }

  ~PortSet() {
    ASSERT(group != 0);

    // Close the group
    port_close(group);

    // Close all open read ports.
    for (size_t i = 0; i < index_map.size(); i++) {
      port_close(port_set[i]);
    }
    free(port_set);

    // Close and destroy the interrupt 'write' end.
    port_close(interrupt_port);
    port_destroy(interrupt_port);
  }

  void AddReadPort(port_t port) {
    word index = index_map.size();
    size_t new_size = (index + 1) * sizeof(port_t);
    port_set = reinterpret_cast<port_t*>(realloc(port_set, new_size));
    port_set[index] = port;
    index_map[port] = index;

    UpdateGroupPort();
  }

  void Interrupt() {
    port_packet_t p;
    memset(&p, 0, sizeof(p));
    port_write(interrupt_port, &p, 1);
  }

  bool Wait(lk_time_t timeout, port_result_t* result) {
    return port_read(group, timeout, result) != ERR_TIMED_OUT;
  }

 private:
  void UpdateGroupPort() {
    if (group != 0) port_close(group);
    port_group(port_set, index_map.size(), &group);
  }

  port_t group;
  port_t interrupt_port;
  port_t* port_set;
  HashMap<port_t, word> index_map;
};

void EventHandler::Create() {
  ASSERT(data_ == NULL);

  PortSet* set = new PortSet();
  id_ = -1;
  data_ = reinterpret_cast<void*>(set);
}

void EventHandler::Interrupt() {
  PortSet* set = reinterpret_cast<PortSet*>(data_);
  set->Interrupt();
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

    PortSet* set = reinterpret_cast<PortSet*>(data_);
    port_result_t result;
    bool has_result = set->Wait(next_timeout, &result);

    {
      ScopedMonitorLock scoped_lock(monitor_);

      if (!running_) {
        delete set;
        data_ = NULL;
        monitor_->Notify();
        return;
      }
    }

    if (has_result) {
      // TODO(ajohnsen): Handle result.
    }

    HandleTimeouts();
  }
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LK)
