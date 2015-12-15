// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#include "src/vm/natives.h"

#include <unistd.h>

#include "src/vm/process.h"

namespace fletch {

BEGIN_NATIVE(UriBase) {
  char* buffer = reinterpret_cast<char*>(malloc(PATH_MAX + 1));
  char* path = getcwd(buffer, PATH_MAX);
  Object* result = Failure::index_out_of_bounds();
  if (path != NULL) {
    int length = strlen(path);
    path[length++] = '/';
    path[length] = 0;
    result = process->NewStringFromAscii(List<const char>(path, length));
  }
  free(buffer);
  return result;
}
END_NATIVE()

}  // namespace fletch

#endif  // defined FLETCH_TARGET_OS_POSIX
