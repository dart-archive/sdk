// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef SERVICE_ONE_H
#define SERVICE_ONE_H

#include <inttypes.h>
#include "struct.h"

class ServiceOne {
 public:
  static void setup();
  static void tearDown();
  static int32_t echo(int32_t arg);
  static void echoAsync(int32_t arg, void (*callback)(int32_t, void*), void* callback_data);
};

#endif  // SERVICE_ONE_H
