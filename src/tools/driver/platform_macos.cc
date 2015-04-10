// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <mach-o/dyld.h>

#include "src/shared/assert.h"

#include "src/tools/driver/platform.h"

namespace fletch {

void GetPathOfExecutable(char* path, size_t path_length) {
  uint32_t bytes_copied = path_length;
  if (_NSGetExecutablePath(path, &bytes_copied) != 0) {
    FATAL1("_NSGetExecutablePath failed, %u bytes left.", bytes_copied);
  }
}

}  // namespace fletch
