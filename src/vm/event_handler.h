// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_EVENT_HANDLER_H_
#define SRC_VM_EVENT_HANDLER_H_

#include "src/shared/globals.h"
#include "src/vm/priority_heap.h"
#include "src/vm/thread.h"

namespace dartino {

class Monitor;
class Port;
class Object;
class Process;

class EventListener {
 public:
  virtual ~EventListener() {}
  virtual void Send(int64 value) = 0;
};

class EventHandler {
 public:
  enum {
    READ_EVENT = 1 << 0,
    WRITE_EVENT = 1 << 1,
    CLOSE_EVENT = 1 << 2,
    ERROR_EVENT = 1 << 3,
  };

  // The possible results of [Add].
  enum class Status {
    OK,
    WRONG_ARGUMENT_TYPE,
    ILLEGAL_STATE,
    INDEX_OUT_OF_BOUNDS,
  };

  static void Setup();
  static void TearDown();
  static EventHandler* GlobalInstance() { return event_handler_; }

  EventHandler();
  ~EventHandler();

  Object* AddPortListener(Process* process, Object* id, Port* port, int flags);

  Status AddEventListener(Object* id, EventListener* event_listener, int flags);

  void ReceiverForPortsDied(Port* port_list);

  void ScheduleTimeout(int64 timeout, Port* port);

  Monitor* monitor() const { return monitor_; }

  static void Send(Port* port, int64 value, bool release_port);

 private:
  // Global EventHandler instance.
  static EventHandler* event_handler_;

  Monitor* monitor_;
  void* data_;
  intptr_t id_;
  bool running_;
  ThreadIdentifier thread_;

  PriorityHeapWithValueIndex<int64, Port*> timeouts_;
  int64 next_timeout_;

  static void* RunEventHandler(void* peer);
  void EnsureInitialized();

  void Create();
  void Run();
  void Interrupt();
  void HandleTimeouts();
};

}  // namespace dartino

#endif  // SRC_VM_EVENT_HANDLER_H_
