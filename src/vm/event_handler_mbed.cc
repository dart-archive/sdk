// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_MBED)

#include "src/vm/event_handler.h"

namespace fletch {

EventHandler::EventHandler()
    : monitor_(NULL),
      fd_(-1),
      read_fd_(-1),
      write_fd_(-1) {
}

EventHandler::~EventHandler() { }

void* RunEventHandler(void* peer) {
  UNIMPLEMENTED();
  return NULL;
}

int EventHandler::GetEventHandler() {
  UNIMPLEMENTED();
  return -1;
}

void EventHandler::Send(Port* port, uword mask) {
  UNIMPLEMENTED();
}

int EventHandler::Create() {
  UNIMPLEMENTED();
  return 0;
}

void EventHandler::Run() {
  UNIMPLEMENTED();
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_MBED)
