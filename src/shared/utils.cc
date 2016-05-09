// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/utils.h"

#include <ctype.h>
#include <stdarg.h>
#include <stdlib.h>

#include "src/shared/version.h"
#include "src/shared/platform.h"

namespace dartino {

Atomic<bool> Print::standard_output_enabled_(true);

#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
Mutex* Print::mutex_ = Platform::CreateMutex();
PrintInterceptor* Print::interceptor_ = NULL;
#endif

void Print::Out(const char* format, ...) {
#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
  va_list args;
  va_start(args, format);
  int size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char* message = reinterpret_cast<char*>(malloc(size + 1));
  va_start(args, format);
  int printed = vsnprintf(message, size + 1, format, args);
  ASSERT(printed == size);
  va_end(args);
  if (standard_output_enabled_) {
    fputs(message, stdout);
    fflush(stdout);
  }
  ScopedLock scope(mutex_);
  for (PrintInterceptor* interceptor = interceptor_; interceptor != NULL;
       interceptor = interceptor->next_) {
    interceptor->Out(message);
  }
  free(message);
#else
  if (standard_output_enabled_) {
    va_list args;
    va_start(args, format);
    vfprintf(stdout, format, args);
    va_end(args);
  }
#endif  // DARTINO_ENABLE_PRINT_INTERCEPTORS
}

void Print::Error(const char* format, ...) {
#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
  va_list args;
  va_start(args, format);
  int size = vsnprintf(NULL, 0, format, args);
  va_end(args);
  char* message = reinterpret_cast<char*>(malloc(size + 1));
  va_start(args, format);
  int printed = vsnprintf(message, size + 1, format, args);
  ASSERT(printed == size);
  va_end(args);
  if (standard_output_enabled_) {
    fputs(message, stderr);
    fflush(stderr);
  }
  ScopedLock scope(mutex_);
  for (PrintInterceptor* interceptor = interceptor_; interceptor != NULL;
       interceptor = interceptor->next_) {
    interceptor->Error(message);
  }
  free(message);
#else
  if (standard_output_enabled_) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
  }
#endif  // DARTINO_ENABLE_PRINT_INTERCEPTORS
}

void Print::RegisterPrintInterceptor(PrintInterceptor* interceptor) {
#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
  ScopedLock scope(mutex_);
  ASSERT(!interceptor->next_);
  interceptor->next_ = interceptor_;
  interceptor_ = interceptor;
#else
  UNIMPLEMENTED();
#endif  // DARTINO_ENABLE_PRINT_INTERCEPTORS
}

void Print::UnregisterPrintInterceptor(PrintInterceptor* interceptor) {
#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
  ScopedLock scope(mutex_);
  if (interceptor == interceptor_) {
    interceptor_ = interceptor->next_;
  } else {
    PrintInterceptor* prev = interceptor_;
    while (prev != NULL && prev->next_ != interceptor) {
      prev = prev->next_;
    }
    if (prev != NULL) {
      prev->next_ = interceptor->next_;
    }
  }
  interceptor->next_ = NULL;
#else
  UNIMPLEMENTED();
#endif  // DARTINO_ENABLE_PRINT_INTERCEPTORS
}

void Print::UnregisterPrintInterceptors() {
#ifdef DARTINO_ENABLE_PRINT_INTERCEPTORS
  ScopedLock scope(mutex_);
  delete interceptor_;
  interceptor_ = NULL;
#endif  // DARTINO_ENABLE_PRINT_INTERCEPTORS
}

uint32 Utils::StringHash(const uint8* data, int length, int char_width) {
  // This implementation is based on the public domain MurmurHash
  // version 2.0. The constants M and R have been determined work
  // well experimentally.
  const uint32 M = 0x5bd1e995;
  const int R = 24;
  int remaining = length;
  uint32 hash = length;

  // We'll be reading up to two bytes at a time. On certain systems that
  // is only allowed if the pointers are properly aligned.
  ASSERT(IsAligned(reinterpret_cast<uword>(data), 4));

  // Mix one char at a time into the hash.
  const uint8* cursor = data;
  while (remaining >= 2) {
    uint32 part = 0;
    if (char_width == 2) {
      part = *reinterpret_cast<const uint32*>(cursor);
    } else {
      part = (*cursor) | (*(cursor + 1) << 16);
    }
    part *= M;
    part ^= part >> R;
    part *= M;
    hash *= M;
    hash ^= part;
    cursor += 2 * char_width;
    remaining -= 2;
  }

  // Handle the last byte of the string if necessary.
  if (remaining != 0) {
    ASSERT(remaining == 1);
    uint32 part =
        (char_width == 2) ? *reinterpret_cast<const uint16*>(cursor) : *cursor;
    part *= M;
    part ^= part >> R;
    part *= M;
    hash *= M;
    hash ^= part;
  }

  // Do a few final mixes of the hash to ensure the last few bytes are
  // well-incorporated.
  hash ^= hash >> 13;
  hash *= M;
  hash ^= hash >> 15;
  return hash;
}

bool Version::Check(const char* vm_version,
                    int vm_version_length,
                    const char* compiler_version,
                    int compiler_version_length,
                    CheckType check) {
  if (check == kExact) {
    return (vm_version_length == compiler_version_length) &&
           (strncmp(vm_version, compiler_version, vm_version_length) == 0);
  } else {
    ASSERT(check == kCompatible);
    const char* v1 = vm_version;
    const char* v2 = compiler_version;
    // Match digits and dots.
    while (*v1 == *v2 &&
           (isdigit(*v1) || *v1 == '.') &&
           (v1 - vm_version) < vm_version_length &&
           (v2 - compiler_version) < compiler_version_length) {
      v1++;
      v2++;
    }
    // Match if first non-match is dash or end of string, and the
    // previous character was a digit (not a dot).
    return (v1 > vm_version) &&
        isdigit(*(v1 - 1)) &&
        (*v1 == '-' || (v1 - vm_version) == vm_version_length) &&
        (*v2 == '-' || (v2 - compiler_version) == compiler_version_length);
  }
}

}  // namespace dartino
