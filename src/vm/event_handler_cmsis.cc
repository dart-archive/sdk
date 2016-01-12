// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_CMSIS)

#include <cmsis_os.h>

#include "src/vm/event_handler.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/shared/platform.h"

namespace fletch {

const uint32_t kInterruptPortId = 0;

class PortMapping {
 public:
  PortMapping() : mapping() {}

  void SetPort(uint32_t port_id, Port *port) {
    Port *existing = mapping[port_id];
    if (existing != NULL) FATAL("Already listening to port");
    mapping[port_id] = port;
  }

  Port *GetPort(uint32_t port_id) {
    return mapping[port_id];
  }

  void RemovePort(uint32_t port_id) {
    mapping.Erase(mapping.Find(port_id));
  }

 private:
  HashMap<uint32_t, Port*> mapping;
};

void EventHandler::Create() {
  data_ = reinterpret_cast<void*>(new PortMapping());
}

void EventHandler::Interrupt() {
  // The interrupt event currently contains no message.
  int64 dummy_message = 0;
  SendMessageCmsis(kInterruptPortId, dummy_message);
}

Object* EventHandler::Add(Process* process, Object* id, Port* port,
                          int flags) {
  if (!id->IsSmi()) return Failure::wrong_argument_type();

  EnsureInitialized();

  int port_id = Smi::cast(id)->value();

  ScopedMonitorLock locker(monitor_);

  reinterpret_cast<PortMapping*>(data_)->SetPort(port_id, port);
  port->IncrementRef();
  return process->program()->null_object();
}

void EventHandler::Run() {
  osMailQId queue = GetFletchMailQ();
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

    osEvent event = osMailGet(queue, next_timeout);
    HandleTimeouts();

    {
      ScopedMonitorLock scoped_lock(monitor_);

      if (!running_) {
        data_ = NULL;
        monitor_->Notify();
        return;
      }
    }

    if (event.status == osEventMail) {
      CmsisMessage *message = reinterpret_cast<CmsisMessage*>(event.value.p);

      int64 value = message->message;
      uint32_t port_id = message->port_id;
      if (port_id != kInterruptPortId) {
        Port *port = reinterpret_cast<PortMapping*>(data_)->GetPort(port_id);
        if (port == NULL) {
          // No listener - drop the event.
        } else {
          reinterpret_cast<PortMapping*>(data_)->RemovePort(port_id);
          Send(port, value, true);
        }
      }
      osMailFree(queue, reinterpret_cast<void*>(message));
    }
  }
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_CMSIS)
