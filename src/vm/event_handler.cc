// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/event_handler.h"

#include "src/shared/utils.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/thread.h"

namespace dartino {

EventHandler* EventHandler::event_handler_ = NULL;

class PortEventListener : public EventListener {
 public:
  explicit PortEventListener(Port *port) : port_(port) {}

  ~PortEventListener() {
    port_->DecrementRef();
  }

  void Send(int64 value) {
    EventHandler::Send(port_, value, false);
  }

 private:
  Port* port_;
};

void EventHandler::Setup() {
  ASSERT(event_handler_ == NULL);
  event_handler_ = new EventHandler();
}

void EventHandler::TearDown() {
  ASSERT(event_handler_ != NULL);
  delete event_handler_;
  event_handler_ = NULL;
}

EventHandler::EventHandler()
    : monitor_(Platform::CreateMonitor()),
      data_(NULL),
      id_(-1),
      running_(true),
      next_timeout_(INT64_MAX) {}

EventHandler::~EventHandler() {
  if (data_ != NULL) {
    ScopedMonitorLock locker(monitor_);
    running_ = false;
    Interrupt();
    while (data_ != NULL) monitor_->Wait();
    thread_.Join();

    // If the [EventHandler] destructor is called, all processes using it should
    // have already died. Therefore all the ports these processes are using
    // should've been removed from the [EventHandler].
    ASSERT(timeouts_.IsEmpty());

    // TODO(ajohnsen/kustermann): The rest of the ports known to the event
    // handler are not associated with timeouts but rather file descriptors. The
    // EventHandler needs to deref them as well after the receiver dies.
  }

  delete monitor_;
}

Object* EventHandler::AddPortListener(
    Process* process, Object* id, Port* port, int wait_mask) {
  port->IncrementRef();
  Status status = AddEventListener(id, new PortEventListener(port), wait_mask);
  switch (status) {
    case Status::OK:
      return process->program()->null_object();
    case Status::WRONG_ARGUMENT_TYPE:
      return Failure::wrong_argument_type();
    case Status::ILLEGAL_STATE:
      return Failure::illegal_state();
    case Status::INDEX_OUT_OF_BOUNDS:
      return Failure::index_out_of_bounds();
    default:
      FATAL("Unexpected return value from Add");
      return NULL;
  }
}

void EventHandler::ReceiverForPortsDied(Port* ports) {
  ScopedMonitorLock locker(monitor_);

  // If there is an active eventhandler instance we'll try to remove
  // our refcount on [port] if necessary.
  if (data_ != NULL) {
    for (Port* port = ports; port != NULL; port = port->next()) {
      if (timeouts_.RemoveByValue(port)) {
        port->DecrementRef();
      }
    }
  }
}

void* EventHandler::RunEventHandler(void* peer) {
  EventHandler* event_handler = reinterpret_cast<EventHandler*>(peer);
  event_handler->Run();
  return NULL;
}

void EventHandler::EnsureInitialized() {
  ScopedMonitorLock locker(monitor_);

  if (data_ == NULL) {
    Create();
    thread_ = Thread::Run(RunEventHandler, reinterpret_cast<void*>(this));
  }
}

// `timeout` is the absolute millisecond that the timeout should fire in terms
// of `Platform::GetMicroseconds / 1000`.
void EventHandler::ScheduleTimeout(int64 timeout, Port* port) {
  ASSERT(timeout != INT64_MAX);

  // Be sure it's running.
  EnsureInitialized();

  ScopedMonitorLock scoped_lock(monitor_);

  if (timeout == -1) {
    if (timeouts_.RemoveByValue(port)) {
      port->DecrementRef();
    } else {
      // If timeout is -1 but we can't find a previous one for the port, we have
      // already acted on it (but hasn't reached Dart yet). Simply ignore it.
      return;
    }
  } else {
    if (timeouts_.InsertOrChangePriority(timeout, port)) {
      port->IncrementRef();
    }
  }

  next_timeout_ =
      timeouts_.IsEmpty() ? INT64_MAX : timeouts_.Minimum().priority;

  Interrupt();
}

void EventHandler::HandleTimeouts() {
  // Check timeouts.
  int64 current_time = Platform::GetMicroseconds() / 1000;

  ScopedMonitorLock scoped_lock(monitor_);
  if (next_timeout_ > current_time) return;

  int64 next_timeout = INT64_MAX;
  while (!timeouts_.IsEmpty()) {
    auto minimum = timeouts_.Minimum();
    if (minimum.priority <= current_time) {
      Send(minimum.value, 0, true);
      timeouts_.RemoveMinimum();
    } else {
      next_timeout = minimum.priority;
      break;
    }
  }
  next_timeout_ = next_timeout;
}

void EventHandler::Send(Port* port, int64 value, bool release_port) {
  port->Lock();
  Process* port_process = port->process();
  if (port_process != NULL) {
    port_process->mailbox()->EnqueueLargeInteger(port, value);
    port_process->program()->scheduler()->ResumeProcess(port_process);
  }
  port->Unlock();
  if (release_port) port->DecrementRef();
}

}  // namespace dartino
