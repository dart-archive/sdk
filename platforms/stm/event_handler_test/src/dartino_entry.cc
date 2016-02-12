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
#include "src/shared/utils.h"

#include "src/shared/platform.h"

extern unsigned char _binary_event_handler_test_snapshot_start;
extern unsigned char _binary_event_handler_test_snapshot_end;
extern unsigned char _binary_event_handler_test_snapshot_size;

extern PageAllocator* page_allocator;

// `MessageQueueProducer` will send a message every `kMessageFrequency`
// millisecond.
const int kMessageFrequency = 400;

// Sends a message on a port_id with a fixed interval.
static void MessageQueueProducer(const void *argument) {
  int handle = reinterpret_cast<int>(argument);
  dartino::Device *device =
      dartino::DeviceManager::GetDeviceManager()->GetDevice(handle);
  uint16_t counter = 0;
  for (;;) {
    counter++;
    device->SetFlag(1);
    osDelay(kMessageFrequency);
  }
  for (;;) {}
}

void NotifyRead(int handle) {
  dartino::Device *device =
      dartino::DeviceManager::GetDeviceManager()->GetDevice(handle);
  device->ClearFlag(1);
}

int InitializeProducer() {
  dartino::Device *device = new dartino::Device(NULL);

  int handle =
      dartino::DeviceManager::GetDeviceManager()->InstallDevice(device);

  osThreadDef(PRODUCER, MessageQueueProducer, osPriorityNormal, 0, 2 * 1024);
  osThreadCreate(osThread(PRODUCER), reinterpret_cast<void*>(handle));

  return handle;
}

DARTINO_EXPORT_TABLE_BEGIN
  DARTINO_EXPORT_TABLE_ENTRY("BSP_LED_On", BSP_LED_On)
  DARTINO_EXPORT_TABLE_ENTRY("BSP_LED_Off", BSP_LED_Off)
  DARTINO_EXPORT_TABLE_ENTRY("initialize_producer", InitializeProducer)
  DARTINO_EXPORT_TABLE_ENTRY("notify_read", NotifyRead)
DARTINO_EXPORT_TABLE_END

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

// Run Dartino on the linked in snapshot.
void StartDartino(void const * argument) {
  dartino::Print::Out("Setup Dartino\n");
  DartinoSetup();
  dartino::Print::Out("Read Dartino snapshot\n");
  unsigned char *snapshot = &_binary_event_handler_test_snapshot_start;
  int snapshot_size =
      reinterpret_cast<int>(&_binary_event_handler_test_snapshot_size);
  DartinoProgram program = DartinoLoadSnapshot(snapshot, snapshot_size);
  dartino::Print::Out("Run Dartino program\n");
  DartinoRunMain(program, 0, NULL);
  dartino::Print::Out("Dartino program exited\n");
}

// Main entry point from FreeRTOS. Running in the default task.
void DartinoEntry(void const * argument) {
  BSP_LED_Init(LED1);

  // Add an arena of the 8Mb of external memory.
  uint32_t ext_mem_arena =
      page_allocator->AddArena("ExtMem", 0xc0000000, 0x800000);

  // Initialize the LCD.
  size_t fb_bytes = (RK043FN48H_WIDTH * RK043FN48H_HEIGHT * 2);
  size_t fb_pages = page_allocator->PagesForBytes(fb_bytes);
  void* fb = page_allocator->AllocatePages(fb_pages, ext_mem_arena);
  BSP_LCD_Init();
  BSP_LCD_LayerDefaultInit(1, reinterpret_cast<uint32_t>(fb));
  BSP_LCD_SelectLayer(1);
  BSP_LCD_SetFont(&LCD_DEFAULT_FONT);

  // Initialize LCD Log module.
  LCD_LOG_Init();
  LCD_LOG_SetHeader(reinterpret_cast<uint8_t*>(const_cast<char*>("Dartino")));
  LCD_LOG_SetFooter(reinterpret_cast<uint8_t*>(const_cast<char*>(
      "STM32746G-Discovery")));

  DartinoRegisterPrintInterceptor(LCDPrintIntercepter, NULL);

  // Always disable standard out, as this will cause infinite
  // recursion in the syscalls.c handling of write.
  dartino::Print::DisableStandardOutput();

  StartDartino(argument);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
