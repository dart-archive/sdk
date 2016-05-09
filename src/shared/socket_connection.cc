// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/socket_connection.h"
#include "src/shared/native_socket.h"
#include "src/shared/utils.h"

namespace dartino {

SocketConnection* SocketConnection::Connect(const char* host, int port) {
  Socket* socket = new Socket();

  if (socket->Connect(host, port)) {
    // We send many small packages, so use no-delay.
    socket->SetTCPNoDelay(true);
    return new SocketConnection(host, port, socket);
  }

  Print::Error("Failed to connect to %s:%i\n", host, port);
  UNREACHABLE();
  return NULL;
}

SocketConnection::~SocketConnection() {
  delete socket_;
}

Connection::Opcode SocketConnection::Receive() {
  incoming_.ClearBuffer();
  uint8* bytes = socket_->Read(5);
  if (bytes == NULL) return kConnectionError;
  int buffer_length = Utils::ReadInt32(bytes);
  Opcode opcode = static_cast<Opcode>(bytes[4]);
  free(bytes);
  if (buffer_length > 0) {
    uint8* buffer = socket_->Read(buffer_length);
    incoming_.SetBuffer(buffer, buffer_length);
    if (buffer == NULL) return kConnectionError;
  }
  return opcode;
}

void SocketConnection::Send(Opcode opcode, const WriteBuffer& buffer) {
  ScopedLock scoped_lock(send_mutex_);
  uint8 header[5];
  Utils::WriteInt32(header, buffer.offset());
  header[4] = opcode;
  socket_->Write(header, 5);
  if (buffer.offset() != 0) {
    socket_->Write(buffer.GetBuffer(), buffer.offset());
  }
}

Connection::Connection() : send_mutex_(Platform::CreateMutex()) {}

SocketConnection::SocketConnection(const char* host, int port, Socket* socket)
    : socket_(socket) {}

ConnectionListener::ConnectionListener(const char* host, int port)
    : socket_(new Socket()), port_(-1) {
  socket_->Bind(host, port);
  port_ = socket_->Listen();
}

ConnectionListener::~ConnectionListener() { delete socket_; }

int ConnectionListener::Port() { return port_; }

Connection* ConnectionListener::Accept() {
  Socket* child = socket_->Accept();
  return new SocketConnection("", 0, child);
}

}  // namespace dartino
