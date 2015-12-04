// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdarg.h>
#include <cmsis_os.h>
#include <include/fletch_api.h>
#include <stm32746g_discovery.h>

#include "fletch_entry.h"
#include "logger.h"

extern unsigned char _binary_snapshot_start;
extern unsigned char _binary_snapshot_end;
extern unsigned char _binary_snapshot_size;

// Run fletch on the linked in snapshot.
void StartFletch(void const * argument) {
  DEBUG_LOG("Setup fletch");
  FletchSetup();
  DEBUG_LOG("Read fletch snapshot");
  unsigned char *snapshot = &_binary_snapshot_start;
  int snapshot_size =  reinterpret_cast<int>(&_binary_snapshot_size);
  FletchProgram program = FletchLoadSnapshot(snapshot, snapshot_size);
  DEBUG_LOG("Run fletch program");
  FletchRunMain(program);
  DEBUG_LOG("Fletch program exited");
}

// Main entry point from FreeRTOS. Running in the default task.
extern "C" void FletchEntry(void const * argument) {
  Logger::Create();

  osThreadDef(START_FLETCH, StartFletch, osPriorityNormal, 0, 1024);
  osThreadCreate(osThread(START_FLETCH), NULL);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
