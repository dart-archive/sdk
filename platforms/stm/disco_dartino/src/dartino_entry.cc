// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>
#include <cmsis_os.h>

#include "include/dartino_api.h"
#include "include/static_ffi.h"

#include "platforms/stm/disco_dartino/src/dartino_entry.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"
#include "platforms/stm/disco_dartino/src/button.h"
#include "platforms/stm/disco_dartino/src/uart.h"

#include "src/shared/utils.h"
#include "src/vm/program_info_block.h"

extern "C" dartino::ProgramInfoBlock program_info_block;
extern "C" char program_start;
extern "C" char program_end;
extern PageAllocator* page_allocator;

Uart *uart;
int uart_handle;

extern "C" size_t UartOpen() {
  return uart_handle;
}

extern "C" size_t UartRead(int handle, uint8_t* buffer, size_t count) {
  return GetUart(handle)->Read(buffer, count);
}

extern "C" size_t UartWrite(
    int handle, uint8_t* buffer, size_t offset, size_t count) {
  return GetUart(handle)->Write(buffer, offset, count);
}

extern "C" uint32_t UartGetError(int handle) {
  return GetUart(handle)->GetError();
}

extern "C" size_t ButtonOpen() {
  Button *button = new Button();
  return button->Open();
}

extern "C" void ButtonNotifyRead(int handle) {
  Button *button = GetButton(handle);
  button->NotifyRead();
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

DARTINO_EXPORT_STATIC_RENAME(uart_open, UartOpen)
DARTINO_EXPORT_STATIC_RENAME(uart_read, UartRead)
DARTINO_EXPORT_STATIC_RENAME(uart_write, UartWrite)
DARTINO_EXPORT_STATIC_RENAME(uart_get_error, UartGetError)
DARTINO_EXPORT_STATIC_RENAME(button_open, ButtonOpen)
DARTINO_EXPORT_STATIC_RENAME(button_notify_read, ButtonNotifyRead)

// Run dartino on the linked in program heap.
void StartDartino(void const * argument) {
  dartino::Print::Out("Setup Dartino\n");
  DartinoSetup();

  dartino::Print::Out("Setting up Dartino program space\n");
  char* heap = &program_start;
  int heap_size = &program_end - heap;
  DartinoProgram program = DartinoLoadProgramFromFlash(
      heap, heap_size + sizeof(dartino::ProgramInfoBlock));

  dartino::Print::Out("Run Dartino program\n");
  DartinoRunMain(program, 0, NULL);
  dartino::Print::Out("Dartino program exited\n");
}

void UartPrintIntercepter(const char* message, int out, void* data) {
  int len = strlen(message);
  for (int i = 0; i < len; i++) {
    if (message[i] == '\n') {
      uart->Write(reinterpret_cast<const uint8_t*>("\r\n"), 0, 1);
    }
    uart->Write(reinterpret_cast<const uint8_t*>(message + i), 0, 1);
  }
}

// Main task entry point from FreeRTOS.
void DartinoEntry(void const * argument) {
  // For now always start the UART.
  uart = new Uart();
  uart_handle = uart->Open();

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
