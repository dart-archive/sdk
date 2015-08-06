// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_EVENT_HANDLER_H_
#define SRC_VM_EVENT_HANDLER_H_

#include "src/shared/globals.h"
#include "src/vm/thread.h"

namespace fletch {

class Monitor;
class Port;

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

  Monitor* monitor() const { return monitor_; }

  int Create();
  void Run();

 private:
  Monitor* monitor_;
  int fd_;
  ThreadIdentifier thread_;

  int read_fd_;
  int write_fd_;

  void Send(Port* port, uword mask);
};

}  // namespace fletch

#endif  // SRC_VM_EVENT_HANDLER_H_
