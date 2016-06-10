// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/uart_connection.h"
#include "src/vm/event_handler.h"
#include "src/vm/object.h"

namespace dartino {

class SemaphoreEventListener : public EventListener {
 public:
  explicit SemaphoreEventListener(osSemaphoreId semaphore)
      : semaphore_(semaphore) {}

  ~SemaphoreEventListener() {}

  void Send(int64 value) {
    osSemaphoreRelease(semaphore_);
  }

 private:
  osSemaphoreId semaphore_;
};

UartConnection* UartConnection::Connect(int uart_handle) {
  return new UartConnection(uart_handle);
}

const int kReceivedBit = 1 << 0;
const int kTransmittedBit = 1 << 1;
const int kErrorBit = 1 << 3;

bool UartConnection::BlockingRead(uint8 *buffer, int count) {
  int read = 0;
  UartDevice *uart = DeviceManager::GetDeviceManager()->GetUart(uart_);
  while (true) {
    if (uart->GetError() != 0) return false;
    read += uart->Read(buffer + read, count - read);
    if (read >= count) break;
    EventHandler::Status status =
        EventHandler::GlobalInstance()->AddEventListener(
            Smi::FromWord(uart_),
            new SemaphoreEventListener(uart_semaphore_),
            kReceivedBit | kErrorBit);
    ASSERT(status == EventHandler::Status::OK);
    osSemaphoreWait(uart_semaphore_, osWaitForever);
  }
  return true;
}

bool UartConnection::BlockingWrite(uint8 *buffer, int count) {
  int written = 0;
  UartDevice *uart = DeviceManager::GetDeviceManager()->GetUart(uart_);
  while (true) {
    if (uart->GetError() != 0) return false;
    written += uart->Write(buffer, written, count - written);
    if (written >= count) break;
    EventHandler::Status status =
        EventHandler::GlobalInstance()->AddEventListener(
            Smi::FromWord(uart_),
            new SemaphoreEventListener(uart_semaphore_),
            kTransmittedBit | kErrorBit);
    ASSERT(status == EventHandler::Status::OK);
    osSemaphoreWait(uart_semaphore_, osWaitForever);
  }
  return true;
}

UartConnection::UartConnection(int uart)
  : uart_(uart),
    uart_semaphore_(osSemaphoreCreate(osSemaphore(uart_semaphore), 1)) {
  // Take the initial semaphore token.
  osSemaphoreWait(uart_semaphore_, osWaitForever);
}

UartConnection::~UartConnection() {
  osSemaphoreDelete(uart_semaphore_);
}

void UartConnection::Send(Opcode opcode, const WriteBuffer& buffer) {
  UartDevice *uart = DeviceManager::GetDeviceManager()->GetUart(uart_);
  ScopedLock scoped_lock(send_mutex_);
  int length = buffer.offset();
  uint8 header[5];
  Utils::WriteInt32(header, length);
  header[4] = opcode;
  uart->Write(header, 0, 5);
  if (length != 0) {
    BlockingWrite(buffer.GetBuffer(), length);
  }
}

Connection::Opcode UartConnection::Receive() {
  incoming_.ClearBuffer();
  uint8 header[5];
  if (!BlockingRead(header, 5)) {
    return kConnectionError;
  }
  int buffer_length = Utils::ReadInt32(header);
  Opcode opcode = static_cast<Opcode>(header[4]);
  if (buffer_length > 0) {
    uint8* buffer = reinterpret_cast<uint8*>(malloc(buffer_length));
    if (!BlockingRead(buffer, buffer_length)) {
      return kConnectionError;
    }
    incoming_.SetBuffer(buffer, buffer_length);
  }
  return opcode;
}

}  // namespace dartino
