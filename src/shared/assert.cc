// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include <stdarg.h>
#include <stdlib.h>

#include "src/shared/utils.h"

namespace fletch {

void DynamicAssertionHelper::Fail(const char* format, ...) {
#ifdef FLETCH_SUPPORT_PRINT_INTERCEPTORS
  // Print out the error.
  Print::Error("%s:%d: error: ", file_, line_);
  va_list arguments;
  va_start(arguments, format);
  char buffer[KB];
  vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  Print::Error("%s\n", buffer);
#else
  va_list arguments;
  va_start(arguments, format);
  fprintf(stderr, "%s:%d: error: ", file_, line_);
  vfprintf(stderr, format, arguments);
  va_end(arguments);
#endif  // FLETCH_SUPPORT_PRINT_INTERCEPTORS

#ifdef FLETCH_TARGET_OS_POSIX
  // In case of failed assertions, abort right away. Otherwise, wait
  // until the program is exiting before producing a non-zero exit
  // code through abort.
  if (kind_ == ASSERT) abort();
  static bool failed = false;
  if (!failed) atexit(abort);
  failed = true;
#else
  abort();
#endif  // FLETCH_TARGET_OS_POSIX
}

}  // namespace fletch
