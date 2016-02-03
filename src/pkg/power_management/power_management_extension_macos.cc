// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_MACOS)

#include <IOKit/pwr_mgt/IOPMLib.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

#include "power_management_extension.h"

int64_t HandleDisableSleep(const char* reason) {
  CFStringRef reasonForActivity =
      CFStringCreateWithCString(NULL, reason, kCFStringEncodingUTF8);

  IOPMAssertionID assertionID;
  IOReturn success = IOPMAssertionCreateWithName(
      kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn,
      reasonForActivity, &assertionID);
  if (success == kIOReturnSuccess) {
    return assertionID;
  } else {
    return -1;
  }
}

void HandleEnableSleep(int64_t disable_id) {
  IOPMAssertionRelease(disable_id);
}

#endif  // DARTINO_TARGET_OS_MACOS
