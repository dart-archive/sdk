// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_UART_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_UART_H_

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include <cinttypes>

#include "platforms/stm/disco_dartino/src/circular_buffer.h"
#include "platforms/stm/disco_dartino/src/device_manager.h"

#include "src/shared/platform.h"


// Interface to the universal asynchronous receiver/transmitter (UART).
class Uart {
 public:
  // Access the UART on the first UART port.
  Uart();

  // Open the uart. Returns the device id used for listening.
  int Open();

  // Read up to `count` bytes from the UART into `buffer` starting at
  // buffer. Return the number of bytes read.
  //
  // This is non-blocking, and will return 0 if no data is available.
  size_t Read(uint8_t* buffer, size_t count);

  // Write up to `count` bytes from the UART into `buffer` starting at
  // buffer. Return the number of bytes written.
  //
  // This is non-blocking, and will return 0 if no data could be written.
  size_t Write(const uint8_t* buffer, size_t offset, size_t count);

  // Return the current error-bits of this device.
  uint32_t GetError();

  void Task();

  void ReturnFromInterrupt(uint32_t flag);

  uint32_t error_;

 private:
  // Send a message to the event-handler with the current flags if there is a
  // registered listing Port.
  void SendMessage();

  void EnsureTransmission();

  uint32_t mask_;

  static const int kTxBlockSize = 10;

  uint8_t read_data_;

  CircularBuffer* read_buffer_;
  CircularBuffer* write_buffer_;

  int handle_ = -1;

  UART_HandleTypeDef* uart_;

  dartino::Device device_;

  // Transmit status.
  dartino::Mutex* tx_mutex_;

  uint8_t tx_data_[kTxBlockSize];  // Buffer send to the HAL.

  // Are we currently waiting for transmission to finish.
  bool tx_pending_;

  // Used to signal new events from the event handler.
  osSemaphoreId semaphore_;

  dartino::Atomic<uint32_t> interrupt_flags;
};

Uart *GetUart(int handle);

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_UART_H_
