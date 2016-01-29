// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <FreeRTOS.h>
#include <task.h>

#include "src/shared/assert.h"

// Hook called by FreeRTOS when a stack overflow is detected.
extern "C" void vApplicationStackOverflowHook(
    xTaskHandle xTask, signed char *pcTaskName) {
  FATAL("Stack overflow.\n");
}

// Hook called by FreeRTOS when allocation failed.
extern "C" void vApplicationMallocFailedHook() {
  FATAL("Out of memory.\n");
}
