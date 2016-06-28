// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_STM32F746G_DISCOVERY_UART_DRIVER_H_
#define SRC_FREERTOS_STM32F746G_DISCOVERY_UART_DRIVER_H_

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include <cinttypes>

#include "src/freertos/circular_buffer.h"
#include "src/freertos/device_manager.h"
#include "src/shared/platform.h"

// Interface to the universal asynchronous receiver/transmitter (UART).
class UartDriverImpl {
 public:
  // Access the UART on the first UART port.
  UartDriverImpl();

  // Initialize the UART.
  void Initialize(uintptr_t device_id);

  // De-initialize the UART.
  void DeInitialize();

  // Read up to `count` bytes from the UART into `buffer` starting at
  // buffer. Return the number of bytes read.
  //
  // This is non-blocking, and will return 0 if no data is available.
  size_t Read(uint8_t* buffer, size_t count);

  // Write up to `count` bytes from the UART into `buffer` starting at
  // `offset`. Return the number of bytes written.
  //
  // This is non-blocking, and will return 0 if no data could be written.
  size_t Write(const uint8_t* buffer, size_t offset, size_t count);

  // Return the current error-bits of this device.
  uint32_t GetError();

  void Task();

  void InterruptHandler();

  uint32_t error_;

 private:
  // Send a message to the event-handler with the current flags if there is a
  // registered listing Port.
  void SendMessage();

  void EnsureTransmission();

  static const int kTxBlockSize = 10;

  uint8_t read_data_;

  CircularBuffer* read_buffer_;
  CircularBuffer* write_buffer_;

  UART_HandleTypeDef* uart_;

  // Device ID returned from device driver registration.
  uintptr_t device_id_;

  // Transmit status.
  dartino::Mutex* tx_mutex_;

  // Bytes we are transmitting.
  // TODO(sigurdm): Avoid this, and just transmit from `write_buffer_`;
  uint8_t tx_data_[kTxBlockSize];

  // Index into tx_data.
  int tx_progress_;
  // Length of data in tx_data.
  int tx_length_;

  // Are we currently waiting for transmission to finish.
  bool tx_pending_;

  // Thread id of the thread that signals the event-handler.
  osThreadId signalThread_;
};

extern "C" void FillUartDriver(UartDriver* driver);

#endif  // SRC_FREERTOS_STM32F746G_DISCOVERY_UART_DRIVER_H_
