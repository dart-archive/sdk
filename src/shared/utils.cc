// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/utils.h"

namespace fletch {

PrintInterceptor* Print::interceptor_ = NULL;

void Print::Out(const char* format, ...) {
  va_list args;
  va_start(args, format);
  int size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char* message = reinterpret_cast<char*>(malloc(size + 1));
  va_start(args, format);
  int printed = vsnprintf(message, size + 1, format, args);
  ASSERT(printed == size);
  va_end(args);
  fputs(message, stdout);
  fflush(stdout);
  if (interceptor_) interceptor_->Out(message);
  free(message);
}

void Print::Error(const char* format, ...) {
  va_list args;
  va_start(args, format);
  int size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char* message = reinterpret_cast<char*>(malloc(size + 1));
  va_start(args, format);
  int printed = vsnprintf(message, size + 1, format, args);
  ASSERT(printed == size);
  va_end(args);
  fputs(message, stderr);
  fflush(stderr);
  if (interceptor_) interceptor_->Error(message);
  free(message);
}

uint32 Utils::StringHash(const uint16* data, int length) {
  // This implementation is based on the public domain MurmurHash
  // version 2.0. The constants M and R have been determined work
  // well experimentally.
  const uint32 M = 0x5bd1e995;
  const int R = 24;
  int size = length * sizeof(uint16);
  uint32 hash = size;

  // We'll be reading four bytes at a time. On certain systems that
  // is only allowed if the pointers are properly aligned.
  ASSERT(IsAligned(reinterpret_cast<uword>(data), 4));

  // Mix four bytes at a time into the hash.
  const uint8* cursor = reinterpret_cast<const uint8*>(data);
  while (size >= 4) {
    uint32 part = *reinterpret_cast<const uint32*>(cursor);
    part *= M;
    part ^= part >> R;
    part *= M;
    hash *= M;
    hash ^= part;
    cursor += 4;
    size -= 4;
  }

  // Handle the last two bytes of the string if necessary.
  if (size != 0) {
    ASSERT(size == 2);
    hash ^= *reinterpret_cast<const uint16*>(cursor);
    hash *= M;
  }

  // Do a few final mixes of the hash to ensure the last few bytes are
  // well-incorporated.
  hash ^= hash >> 13;
  hash *= M;
  hash ^= hash >> 15;
  return hash;
}

}  // namespace fletch
