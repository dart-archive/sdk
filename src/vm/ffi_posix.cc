// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/ffi.h"

#include <libgen.h>

namespace fletch {

char* ForeignUtils::DirectoryName(char* path) {
  return dirname(path);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_POSIX)
