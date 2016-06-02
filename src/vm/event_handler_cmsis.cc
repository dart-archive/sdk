// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_CMSIS)

#include <cmsis_os.h>

// TODO(sigurdm): The cmsis event-handler should not know about the
// disco-platform
#include "platforms/stm/disco_dartino/src/device_manager.h"

#include "src/vm/event_handler.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"

namespace dartino {

// Event value for interruption.
// Sending a message with this value signals an interruption of the
// event-handler.
const uint32_t kInterruptHandle = 0;

// Dummy-class. Currently we don't store anything in EventHandler::data_. But
// if we set it to NULL, EventHandler::EnsureInitialized will not realize it is
// initialized.
class Data {};

DeviceManager* DeviceManager::instance_;

void EventHandler::Create() {
  data_ = reinterpret_cast<void*>(new Data());
}

void EventHandler::Interrupt() {
  if (DeviceManager::GetDeviceManager()->SendMessage(kInterruptHandle) !=
      osOK) {
    FATAL("Could not send Interrupt");
  }
}

EventHandler::Status EventHandler::AddEventListener(
    Object* id,
    EventListener* event_listener,
    int wait_mask) {
  if (!id->IsSmi()) {
    delete event_listener;
    return Status::WRONG_ARGUMENT_TYPE;
  }
  EnsureInitialized();

  int handle = Smi::cast(id)->value();

  bool success =
      DeviceManager::GetDeviceManager()->SetEventListener(
          handle, wait_mask, event_listener);
  if (!success) {
    delete event_listener;
    return Status::ILLEGAL_STATE;
  }

  return Status::OK;
}

void EventHandler::Run() {
  osMessageQId queue = DeviceManager::GetDeviceManager()->GetMailQueue();

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

    osEvent event = osMessageGet(queue, static_cast<int>(next_timeout));
    HandleTimeouts();

    {
      ScopedMonitorLock scoped_lock(monitor_);

      if (!running_) {
        data_ = NULL;
        monitor_->Notify();
        return;
      }
    }

    if (event.status == osEventMessage) {
      if (event.value.v != kInterruptHandle) {
        Event* e = reinterpret_cast<Event*>(event.value.p);
        e->event_listener->Send(e->flags);
        delete e;
      }
    }
  }
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_CMSIS)
