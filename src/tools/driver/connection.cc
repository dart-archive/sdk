// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/tools/driver/connection.h"

#include <cstdlib>

#include "src/shared/native_socket.h"
#include "src/shared/utils.h"

namespace fletch {

DriverConnection::DriverConnection(Socket* socket)
    : socket_(socket) {
}

DriverConnection::~DriverConnection() {
  delete socket_;
}

DriverConnection::Command DriverConnection::Receive() {
  incoming_.ClearBuffer();
  uint8* bytes = socket_->Read(5);
  if (bytes == NULL) return kDriverConnectionError;
  int buffer_length = Utils::ReadInt32(bytes);
  Command command = static_cast<Command>(bytes[4]);
  free(bytes);
  if (buffer_length > 0) {
    uint8* buffer = socket_->Read(buffer_length);
    incoming_.SetBuffer(buffer, buffer_length);
    if (buffer == NULL) return kDriverConnectionError;
  }
  return command;
}

void DriverConnection::Send(Command command) {
  uint8 header[5];
  Utils::WriteInt32(header, outgoing_.offset());
  header[4] = command;
  socket_->Write(header, 5);
  outgoing_.WriteTo(socket_);
}

}  // namespace fletch
