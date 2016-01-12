// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include <cmsis_os.h>
#include <stm32746g_discovery.h>

#include "include/fletch_api.h"
#include "include/static_ffi.h"

#include "platforms/stm/disco_fletch/src/fletch_entry.h"
#include "platforms/stm/disco_fletch/src/logger.h"
#include "platforms/stm/disco_fletch/src/uart.h"

#include "src/shared/platform.h"

extern unsigned char _binary_event_handler_test_snapshot_start;
extern unsigned char _binary_event_handler_test_snapshot_end;
extern unsigned char _binary_event_handler_test_snapshot_size;

// `MessageQueueProducer` will send a message every `kMessageFrequency`
// millisecond.
const int kMessageFrequency = 400;

// Sends a message on a port_id with a fixed interval.
static void MessageQueueProducer(const void *argument) {
  uint16_t counter = 0;
  for (;;) {
    counter++;
    int port_id = 1;
    int status = fletch::SendMessageCmsis(port_id, counter);
    if (status != osOK) {
      LOG_DEBUG("Error Sending %d\n", status);
    }
    osDelay(kMessageFrequency);
  }
}

FLETCH_EXPORT_TABLE_BEGIN
  FLETCH_EXPORT_TABLE_ENTRY("BSP_LED_On", BSP_LED_On)
  FLETCH_EXPORT_TABLE_ENTRY("BSP_LED_Off", BSP_LED_Off)
FLETCH_EXPORT_TABLE_END

// Run fletch on the linked in snapshot.
void StartFletch(void const * argument) {
  LOG_DEBUG("Setup fletch\n");
  FletchSetup();
  LOG_DEBUG("Read fletch snapshot\n");
  unsigned char *snapshot = &_binary_event_handler_test_snapshot_start;
  int snapshot_size =
      reinterpret_cast<int>(&_binary_event_handler_test_snapshot_size);
  FletchProgram program = FletchLoadSnapshot(snapshot, snapshot_size);
  LOG_DEBUG("Run fletch program\n");
  FletchRunMain(program);
  LOG_DEBUG("Fletch program exited\n");
}

// Main entry point from FreeRTOS. Running in the default task.
extern "C" void FletchEntry(void const * argument) {
  BSP_LED_Init(LED1);

  Logger::Create();
  fletch::Platform::Setup();
  osThreadDef(START_FLETCH, StartFletch, osPriorityNormal, 0,
              3 * 1024 /* stack size */);
  osThreadCreate(osThread(START_FLETCH), NULL);

  osThreadDef(PRODUCER, MessageQueueProducer, osPriorityNormal, 0, 2 * 1024);
  osThreadCreate(osThread(PRODUCER), NULL);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
