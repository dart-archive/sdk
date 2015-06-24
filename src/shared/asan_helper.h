// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ASAN_HELPER_H_
#define SRC_SHARED_ASAN_HELPER_H_

#if defined(__has_feature)
#if __has_feature(address_sanitizer)

#include <sanitizer/lsan_interface.h>

#define ADDRESS_SANITIZER_SUPPORT

#if defined(FLETCH_ASAN) && defined(FLETCH_CLANG)
#define USING_ADDRESS_SANITIZER
#endif

// NOTE: We don't have defines for the host/target operating system, but the
// leak sanitizer seems to be only enabled on Linux 64-bit.
// Since we can't distinguish between MacOS/Linux, we use PROBABLY_*
#if defined(FLETCH_ASAN) && defined(FLETCH_CLANG) && defined(FLETCH_TARGET_X64)
#define PROBABLY_USING_LEAK_SANITIZER
#endif

#endif  // __has_feature(address_sanitizer)
#endif  // defined(__has_feature)

#if defined(FLETCH_ASAN) && \
    defined(FLETCH_CLANG) && \
    defined(FLETCH_TARGET_X64) && \
    !defined(USING_ADDRESS_SANITIZER)
#error "Expected to use ASAN in asan-clang-x64 configuration."
#endif

#endif  // SRC_SHARED_ASAN_HELPER_H_

