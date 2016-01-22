// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_WIN)

#include "src/vm/natives.h"

#include <direct.h>

#include "src/shared/platform.h"

#include "src/vm/process.h"

namespace fletch {

BEGIN_NATIVE(UriBase) {
  char* buffer = reinterpret_cast<char*>(malloc(MAXPATHLEN + 1));
  char* path = _getcwd(buffer, MAXPATHLEN);
  if (path == NULL) FATAL("Failed to get current working directory.");
  int length = strlen(path);
  if (path[length - 1] != '\\') {
    path[length++] = '\\';
    path[length] = 0;
  }
  Object* result = process->NewStringFromAscii(List<const char>(path, length));
  free(buffer);
  return result;
}
END_NATIVE()

}  // namespace fletch

#endif  // defined FLETCH_TARGET_OS_WIN
