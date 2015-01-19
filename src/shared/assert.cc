// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include <stdarg.h>
#include <cstdlib>
#include <sstream>
#include <string>

namespace fletch {

void DynamicAssertionHelper::Fail(const char* format, ...) {
  std::stringstream stream;
  stream << file_ << ":" << line_ << ": error: ";

  va_list arguments;
  va_start(arguments, format);
  char buffer[KB];
  vsnprintf(buffer, sizeof(buffer), format, arguments);
  va_end(arguments);
  stream << buffer << std::endl;

  // Get the message from the string stream and dump it on stderr.
  std::string message = stream.str();
  fprintf(stderr, "%s", message.c_str());

  // In case of failed assertions, abort right away. Otherwise, wait
  // until the program is exiting before producing a non-zero exit
  // code through abort.
  if (kind_ == ASSERT) std::abort();
  static bool failed = false;
  if (!failed) std::atexit(std::abort);
  failed = true;
}

}  // namespace fletch
