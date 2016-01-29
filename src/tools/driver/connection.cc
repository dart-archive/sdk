// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/tools/driver/connection.h"

#include <errno.h>
#include <unistd.h>

#include "src/shared/native_socket.h"
#include "src/shared/utils.h"

namespace fletch {

DriverConnection::DriverConnection(Socket* socket) : socket_(socket) {}

DriverConnection::~DriverConnection() { delete socket_; }

DriverConnection::Command DriverConnection::Receive() {
  incoming_.ClearBuffer();
  uint8 header[kHeaderSize];
  size_t offset = 0;
  int fd = socket_->FileDescriptor();
  while (offset < sizeof(header)) {
    int bytes =
        TEMP_FAILURE_RETRY(read(fd, header + offset, sizeof(header) - offset));
    if (bytes == 0) {
      return kDriverConnectionClosed;
    } else if (bytes < 0) {
      return kDriverConnectionError;
    }
    offset += bytes;
  }
  int buffer_length = Utils::ReadInt32(header);
  Command command = static_cast<Command>(header[4]);
  if (buffer_length > 0) {
    uint8* buffer = socket_->Read(buffer_length);
    incoming_.SetBuffer(buffer, buffer_length);
    if (buffer == NULL) return kDriverConnectionError;
  }
  return command;
}

void DriverConnection::Send(Command command, const WriteBuffer& buffer) {
  uint8 header[5];
  Utils::WriteInt32(header, buffer.offset());
  header[4] = command;
  socket_->Write(header, 5);
  buffer.WriteTo(socket_);
}

}  // namespace fletch
