// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/event_handler.h"

#include <unistd.h>

namespace fletch {

void EventHandler::Interrupt() {
  int* fds = reinterpret_cast<int*>(data_);
  char b = 0;
  TEMP_FAILURE_RETRY(write(fds[1], &b, 1));
}

Object* EventHandler::Add(Process* process, Object* id, Port* port) {
  // TODO(ajohnsen): Use this for enqueuing fd's in the event handler.
  // TODO(ajohnsen): Take an option mask for options (one-shot, etc)?
  UNIMPLEMENTED();
  return NULL;
}

}  // namespace fletch

#endif  // FLETCH_TARGET_OS_POSIX
