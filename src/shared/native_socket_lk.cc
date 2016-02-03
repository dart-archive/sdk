// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LK) && defined(DARTINO_ENABLE_LIVE_CODING)

#include "src/shared/native_socket.h"

#include <stdlib.h>
// TODO(ajohnsen): Should not be required:
extern "C" {
#include <lib/minip.h>
}

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace dartino {

struct Socket::SocketData {
  SocketData() : socket(NULL), port(-1) {}
  SocketData(tcp_socket_t* socket, int port) : socket(socket), port(port) {}

  tcp_socket_t* socket;
  int port;
};

Socket::Socket() : data_(new SocketData()) {}

Socket* Socket::FromFd(int id) {
  UNIMPLEMENTED();
  return NULL;
}

Socket::Socket(SocketData* data) : data_(data) {}

Socket::~Socket() {
  if (data_->socket != NULL) tcp_close(data_->socket);
  delete data_;
}

bool Socket::Connect(const char* host, int port) {
  UNIMPLEMENTED();
  return false;
}

void Socket::Bind(const char* host, int port) { data_->port = port; }

int Socket::Listen() {
  int port = data_->port;
  status_t status = tcp_open_listen(&data_->socket, port);
  if (status != 0) FATAL1("Failed Socket::Listen: %i", status);
  return port;
}

Socket* Socket::Accept() {
  tcp_socket_t* client = NULL;
  int status = tcp_accept(data_->socket, &client);
  if (status != 0) FATAL1("Failed Socket::Accept: %i", status);
  SocketData* data = new SocketData(client, 0);
  return new Socket(data);
}

void Socket::Write(uint8* data, int length) {
  int offset = 0;
  while (offset < length) {
    int bytes = tcp_write(data_->socket, data + offset, length - offset);
    if (bytes < 0) {
      Print::Error("Failed to write to socket: %p\n", data_->socket);
      UNREACHABLE();
    }
    offset += bytes;
  }
}

uint8* Socket::Read(int length) {
  uint8* data = static_cast<uint8*>(malloc(length));
  int offset = 0;
  while (offset < length) {
    int bytes = tcp_read(data_->socket, data + offset, length - offset);
    if (bytes <= 0) {
      Print::Error("Failed to read from socket\n");
      free(data);
      return NULL;
    }
    offset += bytes;
  }
  return data;
}

int Socket::FileDescriptor() {
  UNIMPLEMENTED();
  return -1;
}

void Socket::SetTCPNoDelay(bool value) {
  // Not available.
}

}  // namespace dartino

#endif  // def'd(DARTINO_TARGET_OS_LK) && def'd(DARTINO_ENABLE_LIVE_CODING)
