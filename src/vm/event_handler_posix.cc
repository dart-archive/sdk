// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_POSIX)

#include "src/vm/event_handler.h"

#include <unistd.h>

namespace dartino {

void EventHandler::Interrupt() {
  int* fds = reinterpret_cast<int*>(data_);
  char b = 0;
  TEMP_FAILURE_RETRY(write(fds[1], &b, 1));
}

}  // namespace dartino

#endif  // DARTINO_TARGET_OS_POSIX
