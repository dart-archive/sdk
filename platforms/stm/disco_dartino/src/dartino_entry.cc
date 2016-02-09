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

extern unsigned char _binary_snapshot_start;
extern unsigned char _binary_snapshot_end;
extern unsigned char _binary_snapshot_size;

extern PageAllocator* page_allocator;

Uart* uart;

extern "C" size_t UartRead(uint8_t* buffer, size_t count) {
  return uart->Read(buffer, count);
}

extern "C" size_t UartWrite(uint8_t* buffer, size_t count) {
  return uart->Write(buffer, count);
}

extern "C" void LCDDrawLine(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
  // BSP_LCD_DrawLine takes uint16_t arguments.
  BSP_LCD_DrawLine(x1, y1, x2, y2);
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
  DARTINO_EXPORT_TABLE_ENTRY("uart_read", UartRead)
  DARTINO_EXPORT_TABLE_ENTRY("uart_write", UartWrite)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_height", BSP_LCD_GetYSize)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_width", BSP_LCD_GetXSize)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_clear", BSP_LCD_Clear)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_read_pixel", BSP_LCD_ReadPixel)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_draw_pixel", BSP_LCD_DrawPixel)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_draw_line", LCDDrawLine)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_draw_circle", BSP_LCD_DrawCircle)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_set_foreground_color", BSP_LCD_SetTextColor)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_set_background_color", BSP_LCD_SetBackColor)
  DARTINO_EXPORT_TABLE_ENTRY("lcd_display_string", BSP_LCD_DisplayStringAt)
DARTINO_EXPORT_TABLE_END

// Run dartino on the linked in snapshot.
void StartDartino(void const * argument) {
  dartino::Print::Out("Setup dartino\n");
  DartinoSetup();
  dartino::Print::Out("Reading dartino snapshot\n");
  unsigned char *snapshot = &_binary_snapshot_start;
  int snapshot_size =  reinterpret_cast<int>(&_binary_snapshot_size);
  DartinoProgram program = DartinoLoadSnapshot(snapshot, snapshot_size);
  dartino::Print::Out("Run dartino program\n");
  DartinoRunMain(program);
  dartino::Print::Out("Dartino program exited\n");
}

void UartPrintIntercepter(const char* message, int out, void* data) {
  int len = strlen(message);
  for (int i = 0; i < len; i++) {
    if (message[i] == '\n') {
      uart->Write(reinterpret_cast<const uint8_t*>("\r"), 1);
    }
    uart->Write(reinterpret_cast<const uint8_t*>(message + i), 1);
  }
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

// Main task entry point from FreeRTOS.
void DartinoEntry(void const * argument) {
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

  // For now always start the UART.
  uart = new Uart();
  uart->Start();

  DartinoRegisterPrintInterceptor(UartPrintIntercepter, NULL);

  // Always disable standard out, as this will cause infinite
  // recursion in the syscalls.c handling of write.
  dartino::Print::DisableStandardOutput();

  StartDartino(argument);

  // No more to do right now.
  for (;;) {
    osDelay(1);
  }
}
