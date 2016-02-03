// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include <cmsis_os.h>
extern "C" {
  #include <lcd_log.h>
}
#include <stm32746g_discovery.h>
#include <stm32746g_discovery_lcd.h>

#include "include/dartino_api.h"
#include "include/static_ffi.h"

#include "platforms/stm/disco_dartino/src/dartino_entry.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"
#include "platforms/stm/disco_dartino/src/uart.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

extern unsigned char _binary_event_handler_test_snapshot_start;
extern unsigned char _binary_event_handler_test_snapshot_end;
extern unsigned char _binary_event_handler_test_snapshot_size;

extern PageAllocator* page_allocator;

// `MessageQueueProducer` will send a message every `kMessageFrequency`
// millisecond.
const int kMessageFrequency = 400;

// Sends a message on a port_id with a fixed interval.
static void MessageQueueProducer(const void *argument) {
  uint16_t counter = 0;
  for (;;) {
    counter++;
    int port_id = 1;
    int status = dartino::SendMessageCmsis(port_id, counter);
    if (status != osOK) {
      dartino::Print::Error("Error Sending %d\n", status);
    }
    osDelay(kMessageFrequency);
  }
}

// Implementation of write used from syscalls.c to redirect all printf
// calls to the print interceptors.
extern "C" int Write(int file, char *ptr, int len) {
  for (int i = 0; i < len; i++) {
    if (file == 2) {
      dartino::Print::Error("%c", *ptr++);
    } else {
      dartino::Print::Out("%c", *ptr++);
    }
  }
  return len;
}

DARTINO_EXPORT_TABLE_BEGIN
  DARTINO_EXPORT_TABLE_ENTRY("BSP_LED_On", BSP_LED_On)
  DARTINO_EXPORT_TABLE_ENTRY("BSP_LED_Off", BSP_LED_Off)
DARTINO_EXPORT_TABLE_END

// Run dartino on the linked in snapshot.
void StartDartino(void const * argument) {
  dartino::Print::Out("Setup dartino\n");
  DartinoSetup();
  dartino::Print::Out("Read dartino snapshot\n");
  unsigned char *snapshot = &_binary_event_handler_test_snapshot_start;
  int snapshot_size =
      reinterpret_cast<int>(&_binary_event_handler_test_snapshot_size);
  DartinoProgram program = DartinoLoadSnapshot(snapshot, snapshot_size);
  dartino::Print::Out("Run dartino program\n");
  DartinoRunMain(program);
  dartino::Print::Out("Dartino program exited\n");
}

// LCDLogPutchar is defined by the STM LCD log utility
// (Utilities/Log/lcd_log.c) by means of the macro definitions of
// LCD_LOG_PUTCHAR in lcd_log_conf.h.
extern "C" int LCDLogPutchar(int ch);
void LCDPrintIntercepter(const char* message, int out, void* data) {
  int len = strlen(message);
  if (out == 3) {
    LCD_LineColor = LCD_COLOR_RED;
  } else {
    LCD_LineColor = LCD_COLOR_BLACK;
  }
  for (int i = 0; i < len; i++) {
    LCDLogPutchar(message[i]);
  }
}

// Main entry point from FreeRTOS. Running in the default task.
void DartinoEntry(void const * argument) {
  // Add an arena of the 8Mb of external memory.
  uint32_t ext_mem_arena =
      page_allocator->AddArena("ExtMem", 0xc0000000, 0x800000);
  BSP_LED_Init(LED1);

  // Initialize the LCD.
  size_t fb_bytes = (RK043FN48H_WIDTH * RK043FN48H_HEIGHT * 2);
  size_t fb_pages = page_allocator->PagesForBytes(fb_bytes);
  void* fb = page_allocator->AllocatePages(fb_pages, ext_mem_arena);
  BSP_LCD_Init();
  BSP_LCD_LayerDefaultInit(1, reinterpret_cast<uint32_t>(fb));
  BSP_LCD_SelectLayer(1);
  BSP_LCD_SetFont(&LCD_DEFAULT_FONT);

  dartino::Platform::Setup();

  // Initialize LCD Log module.
  LCD_LOG_Init();
  LCD_LOG_SetHeader(reinterpret_cast<uint8_t*>(const_cast<char*>("Dartino")));
  LCD_LOG_SetFooter(reinterpret_cast<uint8_t*>(const_cast<char*>(
      "STM32746G-Discovery")));
  DartinoRegisterPrintInterceptor(LCDPrintIntercepter, NULL);
  dartino::Print::DisableStandardOutput();

  osThreadDef(START_DARTINO, StartDartino, osPriorityNormal, 0,
              3 * 1024 /* stack size */);
  osThreadCreate(osThread(START_DARTINO), NULL);

  osThreadDef(PRODUCER, MessageQueueProducer, osPriorityNormal, 0, 2 * 1024);
  osThreadCreate(osThread(PRODUCER), NULL);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
