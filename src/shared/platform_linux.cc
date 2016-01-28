// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#include "src/shared/assert.h"
#include "src/shared/platform.h"

namespace fletch {

void GetPathOfExecutable(char* path, size_t path_length) {
  ssize_t length = readlink("/proc/self/exe", path, path_length - 1);
  if (length == -1) {
    FATAL1("readlink failed: %s", strerror(errno));
  }
  if (static_cast<size_t>(length) == path_length - 1) {
    FATAL("readlink returned too much data");
  }
  path[length] = '\0';
}

int Platform::GetLocalTimeZoneOffset() {
  // TODO(ajohnsen): avoid excessive calls to tzset?
  tzset();
  // Even if the offset was 24 hours it would still easily fit into 32 bits.
  // Note that Unix and Dart disagree on the sign.
  return static_cast<int>(-timezone);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LINUX)
