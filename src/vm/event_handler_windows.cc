// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_WIN)

#include <winsock2.h>

#include "src/vm/event_handler.h"

#include "src/shared/atomic.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/hash_set.h"
#include "src/vm/thread.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace dartino {

// Used to store information about the reason for an event.
struct EventHandlerInfo {
  // Currently we only have sockets as event source.
  SOCKET socket;
  // The associated event we are waiting on.
  HANDLE event;
  // The wait handle needed to unregister this wait.
  HANDLE wait_handle;
  // The port to notify.
  Port* port;

  struct EventHandlerInfo* next;
  struct EventHandlerData* data;
};

typedef HashSet<EventHandlerInfo*> EventHandlerInfoSet;

struct EventHandlerData {
  // Event to interrupt the event loop's wait.
  HANDLE control_event;
  // List of events that have fired in the meantime.
  Atomic<EventHandlerInfo*> signaled;
  // List of all events that we have registered.
  EventHandlerInfoSet allocated;
};

void CALLBACK EventHandlerCallback(void* parameter, BOOLEAN was_timeout) {
  EventHandlerInfo* info = reinterpret_cast<EventHandlerInfo*>(parameter);
  EventHandlerData* data = info->data;

  // Insert the info structure into the signaled list.
  EventHandlerInfo* head = data->signaled.load(kAcquire);
  do {
    info->next = head;
  } while (!data->signaled.compare_exchange_weak(head, info, kAcqRel));

  // Signal the event handler that we have added new information.
  ASSERT(SetEvent(info->data->control_event) != 0);
}

void EventHandler::Create() {
  EventHandlerData* data = new EventHandlerData();
  data->control_event = CreateEvent(NULL, FALSE, FALSE, NULL);
  if (data->control_event == NULL) {
    FATAL1("Cannot create event for event manager: %d", GetLastError());
  }
  data_ = reinterpret_cast<void*>(data);
}

void EventHandler::Interrupt() {
  EventHandlerData* data = reinterpret_cast<EventHandlerData*>(data_);
  ASSERT(data != NULL);
  // Signal the thread that something happened.
  ASSERT(SetEvent(data->control_event) != 0);
}

void EventHandler::Run() {
  EventHandlerData* data = reinterpret_cast<EventHandlerData*>(data_);

  while (true) {
    int64 next_timeout;
    {
      ScopedMonitorLock locker(monitor_);
      next_timeout = next_timeout_;
    }

    DWORD sleep_duration_ms;
    if (next_timeout == INT64_MAX) {
      sleep_duration_ms = INFINITE;
    } else {
      sleep_duration_ms = next_timeout - Platform::GetMicroseconds() / 1000;
      if (sleep_duration_ms < 0) sleep_duration_ms = 0;
    }

    int status = WaitForSingleObject(data->control_event, sleep_duration_ms);


    HandleTimeouts();

    if (!running_) {
      ScopedMonitorLock locker(monitor_);

      // Delete data structures and cancel all pending waits.
      for (auto it = data->allocated.Begin();
           it != data->allocated.End();
           ++it) {
        EventHandlerInfo* info = *it;
        // Unregister the event and wait for pending callbacks.
        UnregisterWaitEx(info->wait_handle, INVALID_HANDLE_VALUE);
        CloseHandle(info->event);
        info->port->DecrementRef();
        // We are tearing down the event handler and the underlying set will be
        // deleted, so it is save to free all info structures.
        delete info;
      }
      CloseHandle(data->control_event);
      delete data;
      data_ = NULL;
      monitor_->Notify();
      return;
    }

    if (status != WAIT_OBJECT_0) continue;

    EventHandlerInfo* infos = data->signaled.exchange(NULL, kAcqRel);

    while (infos != NULL) {
      WSANETWORKEVENTS network_events;
      int status = WSAEnumNetworkEvents(infos->socket, infos->event,
                                        &network_events);
      ASSERT(status == 0);
      LONG events = network_events.lNetworkEvents;
      int64 mask = 0;
      if ((events & FD_READ) != 0) mask |= READ_EVENT;
      if ((events & FD_WRITE) != 0) mask |= WRITE_EVENT;
      if ((events & FD_CLOSE) != 0) mask |= CLOSE_EVENT;

      Send(infos->port, mask, true);

      {
        ScopedMonitorLock locker(monitor_);
        data->allocated.Erase(data->allocated.Find(infos));
      }
      // We can use UnregisterWait here, as we know that the callback has
      // completed.
      UnregisterWait(infos->wait_handle);
      CloseHandle(infos->event);
      infos->port->DecrementRef();
      EventHandlerInfo* next = infos->next;
      delete infos;
      infos = next;
    }
  }
}

Object* EventHandler::Add(Process* process, Object* id, Port* port,
                          int flags) {
  EnsureInitialized();

  EventHandlerData* data = reinterpret_cast<EventHandlerData*>(data_);

  word socket_int;
  if (id->IsSmi()) {
    socket_int = Smi::cast(id)->value();
  } else if (id->IsLargeInteger()) {
    socket_int = LargeInteger::cast(id)->value();
  } else {
    return Failure::wrong_argument_type();
  }

  SOCKET socket = static_cast<SOCKET>(socket_int);

  struct EventHandlerInfo* info = new EventHandlerInfo();

  info->socket = socket;
  info->event = CreateEvent(NULL, FALSE, FALSE, NULL);
  if (info->event == NULL) {
    delete info;
    return Failure::index_out_of_bounds();
  }
  info->port = port;
  info->data = data;

  LONG event_flags = 0;

  if ((flags & ~(READ_EVENT | WRITE_EVENT)) != 0) {
    return Failure::illegal_state();
  }
  if ((flags & READ_EVENT) != 0) event_flags |= FD_READ | FD_ACCEPT;
  if ((flags & WRITE_EVENT) != 0) event_flags |= FD_WRITE;

  if (WSAEventSelect(info->socket, info->event, event_flags) != 0) {
    CloseHandle(info->event);
    delete info;
    return Failure::index_out_of_bounds();
  }

  {
    ScopedMonitorLock locker(monitor_);
    BOOL status = RegisterWaitForSingleObject(
                    &(info->wait_handle),
                    info->event,
                    EventHandlerCallback,
                    reinterpret_cast<void*>(info),
                    INFINITE,
                    WT_EXECUTEINWAITTHREAD | WT_EXECUTEONLYONCE);
    if (status == 0) {
      delete info;
      return Failure::index_out_of_bounds();
    }

    port->IncrementRef();

    data->allocated.Insert(info);
  }

  return process->program()->null_object();
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_WIN)
