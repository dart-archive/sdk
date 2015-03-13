// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>

#include "src/shared/assert.h"

#include "src/tools/driver/get_path_of_executable.h"

namespace fletch {

void GetPathOfExecutable(char* path, size_t path_length) {
  if (readlink("/proc/self/exe", path, path_length) < 0) {
    FATAL1("readlink failed: %s", strerror(errno));
  }
}

}  // namespace fletch
