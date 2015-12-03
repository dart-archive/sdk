// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_EVENT_HANDLER_H_
#define SRC_VM_EVENT_HANDLER_H_

#include "src/shared/globals.h"
#include "src/vm/priority_heap.h"
#include "src/vm/thread.h"

namespace fletch {

class Monitor;
class Port;
class Object;
class Process;

class EventHandler {
 public:
  enum {
    READ_EVENT        = 1 << 0,
    WRITE_EVENT       = 1 << 1,
    CLOSE_EVENT       = 1 << 2,
    ERROR_EVENT       = 1 << 3,
  };

  EventHandler();
  ~EventHandler();

  int GetEventHandler();

  Object* Add(Process* process, Object* id, Port* port);

  void ReceiverForPortsDied(Port* port_list);

  void ScheduleTimeout(int64 timeout, Port* port);

  Monitor* monitor() const { return monitor_; }

 private:
  Monitor* monitor_;
  void* data_;
  int id_;
  bool running_;
  ThreadIdentifier thread_;

  PriorityHeapWithValueIndex<int64, Port*> timeouts_;
  int64 next_timeout_;

  static void* RunEventHandler(void* peer);

  void Create();

  void Run();

  void Interrupt();
  void HandleTimeouts();

  void Send(Port* port, int64 value);
};

}  // namespace fletch

#endif  // SRC_VM_EVENT_HANDLER_H_
