// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

#include "power_management_extension.h"

// Dummy implementation for Linux.
int64_t HandleDisableSleep(const char* reason) {
  // Currently not implemented on Linux.
  return 0;
}

// Dummy implementation for Linux.
void HandleEnableSleep(int64_t disable_id) {
  // Currently not implemented on Linux.
}

#endif  // FLETCH_TARGET_OS_LINUX
