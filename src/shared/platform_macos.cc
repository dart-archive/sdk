// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_MACOS)

#include <mach-o/dyld.h>

#include <CoreFoundation/CFTimeZone.h>

#include "src/shared/assert.h"
#include "src/shared/platform.h"

namespace dartino {

void GetPathOfExecutable(char* path, size_t path_length) {
  uint32_t bytes_copied = path_length;
  if (_NSGetExecutablePath(path, &bytes_copied) != 0) {
    FATAL1("_NSGetExecutablePath failed, %u bytes left.", bytes_copied);
  }
}

int Platform::GetLocalTimeZoneOffset() {
  CFTimeZoneRef tz = CFTimeZoneCopySystem();
  // Even if the offset was 24 hours it would still easily fit into 32 bits.
  int offset = CFTimeZoneGetSecondsFromGMT(tz, CFAbsoluteTimeGetCurrent());
  CFRelease(tz);
  // Note that Unix and Dart disagree on the sign.
  return static_cast<int>(-offset);
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_OS_MACOS)
