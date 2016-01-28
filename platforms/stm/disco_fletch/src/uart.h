// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_UART_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_UART_H_

#include <inttypes.h>

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include "platforms/stm/disco_fletch/src/circular_buffer.h"

// Interface to the universal asynchronous receiver/transmitter
// (UART).
class Uart {
 public:
  // Access the UART on the first UART port.
  Uart();

  // Start processing the UART.
  void Start();

  // Read up to count bytes from the UART into the buffer starting at
  // buffer.
  //
  // This will block until at least one byte can be read.
  size_t Read(uint8_t* buffer, size_t count);


  // Read up to count bytes from the buffer starting at buffer to the
  // UART.
  //
  // This will block until at least one byte can be written.
  size_t Write(const uint8_t* buffer, size_t count);

 private:
  static const int kTxBlockSize = 10;

  void Task();

  void EnsureTransmission();

  UART_HandleTypeDef* uart_;
  int error_count_;
  osSemaphoreDef(semaphore_def_);
  osSemaphoreId(semaphore_);

  // Receive status.
  uint8_t rx_data_;  // The one byte received at the time.
  CircularBuffer* rx_buffer_;

  // Transmit status.
  fletch::Mutex* tx_mutex_;
  uint8_t tx_data_[kTxBlockSize];  // Buffer send to the HAL.
  bool tx_pending_;
  CircularBuffer* tx_buffer_;

  friend void __UartTask(const void*);
};

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_UART_H_
