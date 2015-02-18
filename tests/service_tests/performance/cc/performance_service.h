// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERFORMANCE_SERVICE_H
#define PERFORMANCE_SERVICE_H

#include <inttypes.h>

class PerformanceService {
 public:
  static void setup();
  static void tearDown();
  static int32_t echo(int32_t n);
  static void echoAsync(int32_t n, void (*callback)(int32_t));
};

#endif  // PERFORMANCE_SERVICE_H
