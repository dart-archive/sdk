// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_UART_CONNECTION_H_
#define SRC_FREERTOS_UART_CONNECTION_H_

#include <cmsis_os.h>

#include "src/freertos/device_manager.h"
#include "src/shared/connection.h"

namespace dartino {

class UartConnection : public Connection {
 public:
  static UartConnection* Connect(int uart_handle);
  void Send(Opcode opcode, const WriteBuffer& buffer);
  Connection::Opcode Receive();

 private:
  explicit UartConnection(int uart);
  ~UartConnection();
  bool BlockingRead(uint8 *buffer, int count);
  bool BlockingWrite(uint8 *buffer, int count);

  osSemaphoreDef(uart_semaphore);

  int uart_;
  osSemaphoreId uart_semaphore_;
};

}  // namespace dartino

#endif  // SRC_FREERTOS_UART_CONNECTION_H_
