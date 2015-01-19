// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cstdio>

#include "src/compiler/string_buffer.h"
#include "src/shared/utils.h"

namespace fletch {

StringBuffer::StringBuffer(Zone* zone)
    : builder_(zone) {
}

const char* StringBuffer::ToString() {
  builder_.Add('\0');
  const char* result = builder_.ToList().data();
  builder_.RemoveLast();
  return result;
}

void StringBuffer::Print(const char* format, ...) {
  va_list arguments;
  va_start(arguments, format);
  VPrint(format, arguments);
  va_end(arguments);
}

void StringBuffer::VPrint(const char *format, va_list arguments) {
  char buffer[1024];
  int written = vsnprintf(buffer, ARRAY_SIZE(buffer), format, arguments);
  for (int i = 0; i < written; i++) builder_.Add(buffer[i]);
}

void StringBuffer::Clear() {
  builder_.Clear();
}

}  // namespace fletch
