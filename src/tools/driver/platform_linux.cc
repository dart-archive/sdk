// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>

#include "src/shared/assert.h"

#include "src/tools/driver/platform.h"

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

}  // namespace fletch
