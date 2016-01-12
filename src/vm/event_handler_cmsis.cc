// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_CMSIS)

#include "src/vm/event_handler.h"

namespace fletch {

void EventHandler::Create() { UNIMPLEMENTED(); }

void EventHandler::Interrupt() { UNIMPLEMENTED(); }

Object* EventHandler::Add(Process* process, Object* id, Port* port,
                          int flags) {
  EnsureInitialized();

  return Failure::illegal_state();
}

void EventHandler::Run() { UNIMPLEMENTED(); }

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_CMSIS)
