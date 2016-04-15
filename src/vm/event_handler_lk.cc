// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LK)

#include "src/vm/event_handler.h"

#include <kernel/event.h>
#include <kernel/port.h>

#include "src/shared/utils.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace dartino {

const char* kDartinoInterruptPortName = "DARTINO_INT";

class PortSet {
 public:
  PortSet() : group(0), port_set(NULL) {
    // Create and add the interrupt port.
    port_create(kDartinoInterruptPortName, PORT_MODE_UNICAST, &interrupt_port);
    port_t interrupt_read;
    port_open(kDartinoInterruptPortName, NULL, &interrupt_read);
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
    // This might time out or the port is destroyed when the group is expanded.
    // Just check for NO_ERROR.
    return port_read(group, timeout, result) == NO_ERROR;
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

EventHandler::Status EventHandler::AddEventListener(
    Object* id, EventListener* event_listener, int flags) {
  EnsureInitialized();

  if (!id->IsOneByteString()) return Status::WRONG_ARGUMENT_TYPE;

  char* str = OneByteString::cast(id)->ToCString();

  if (flags != READ_EVENT) {
    delete event_listener;
    Print::Error("Only READ_EVENT is current supported on LK");
    return Status::ILLEGAL_STATE;
  }
  port_t read_port;
  if (port_open(str, event_listener, &read_port) != 0) {
    free(str);
    delete event_listener;
    return Status::INDEX_OUT_OF_BOUNDS;
  }
  free(str);

  PortSet* set = reinterpret_cast<PortSet*>(data_);

  ScopedMonitorLock locker(monitor_);
  set->AddReadPort(read_port);
  set->Interrupt();

  return Status::OK;
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

    if (has_result && result.ctx != NULL) {
      int64 value;
      memcpy(&value, result.packet.value, sizeof(value));
      EventListener* event_listener =
          reinterpret_cast<EventListener*>(result.ctx);
      event_listener->Send(value);
      delete event_listener;
    }

    HandleTimeouts();
  }
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_LK)
