// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef POWER_MANAGEMENT_EXTENSION_H_
#define POWER_MANAGEMENT_EXTENSION_H_

#include "include/dart_api.h"
#include "include/dart_native_api.h"

int64_t HandleDisableSleep(const char* reason);
void HandleEnableSleep(int64_t disable_id);

#endif  // POWER_MANAGEMENT_EXTENSION_H_
