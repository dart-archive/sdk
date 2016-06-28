// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <FreeRTOS.h>
#include <task.h>

#include "src/freertos/cmpctmalloc.h"
#include "src/shared/assert.h"

// Hook called by FreeRTOS when a stack overflow is detected.
extern "C" void vApplicationStackOverflowHook(
    xTaskHandle xTask, signed char *pcTaskName) {
  FATALV("Stack overflow in %s.\n", pcTaskName);
}

// Hook called by FreeRTOS when allocation failed.
extern "C" void vApplicationMallocFailedHook() {
  FATAL("Out of memory.\n");
}

extern "C" void *pvPortMalloc(size_t size) {
  void *pvReturn;
  vTaskSuspendAll();

  pvReturn = cmpct_alloc(size);
  traceMALLOC(pvReturn, size);

  xTaskResumeAll();

  return pvReturn;
}

extern "C" void vPortFree(void *ptr) {
  vTaskSuspendAll();

  cmpct_free(ptr);
  traceFREE(ptr, 0);

  xTaskResumeAll();
}

extern "C" void *suspendingRealloc(void *ptr, size_t size) {
  void *pvReturn;
  vTaskSuspendAll();

  pvReturn = cmpct_realloc(ptr, size);

  xTaskResumeAll();

  return pvReturn;
}
