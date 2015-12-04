// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "fletch_entry.h"

#include <cmsis_os.h>
#include <include/fletch_api.h>
#include <stdarg.h>
#include <stm32746g_discovery.h>

extern unsigned char _binary_snapshot_start;
extern unsigned char _binary_snapshot_end;
extern unsigned char _binary_snapshot_size;

// Run fletch on the linked in snapshot.
void StartFletch(void const * argument) {
  FletchSetup();
  unsigned char *snapshot = &_binary_snapshot_start;
  int snapshot_size =  reinterpret_cast<int>(&_binary_snapshot_size);
  FletchProgram program = FletchLoadSnapshot(snapshot, snapshot_size);
  FletchRunMain(program);
}

// Main entry point from FreeRTOS. Running in the default task.
extern "C" void FletchEntry(void const * argument) {
  osThreadDef(START_FLETCH, StartFletch, osPriorityNormal, 0, 1024);
  osThreadCreate(osThread(START_FLETCH), NULL);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
