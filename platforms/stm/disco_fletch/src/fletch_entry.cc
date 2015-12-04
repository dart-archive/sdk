// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdarg.h>

#include "cmsis_os.h"
#include "stm32746g_discovery.h"

#include "fletch_entry.h"
#include "logger.h"

// Simple task blinking the green LED.
void BlinkTask(void const * argument) {
  int count = 0;
  for (;;) {
    LOG(static_cast<Logger::Level>(count % 5), (char *)"%d\n", count);
    count++;
    osDelay(500);
    BSP_LED_Toggle(LED1);
  }
}

// Main entry point from FreeRTOS. Running in the default task.
extern "C" void FletchEntry(void const * argument) {
  BSP_LED_Init(LED1);

  Logger::Create();

  // Start a task blinking the green LED.
  osThreadDef(
      BLINK_TASK, BlinkTask, osPriorityNormal, 0, configMINIMAL_STACK_SIZE);
  osThreadCreate(osThread(BLINK_TASK), NULL);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
