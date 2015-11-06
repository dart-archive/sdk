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

}  // namespace fletch

#endif  // FLETCH_TARGET_OS_POSIX
