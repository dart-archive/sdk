// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_WIN) && defined(FLETCH_ENABLE_LIVE_CODING)

#include "src/shared/native_socket.h"

#include <winsock2.h>
#include <ws2tcpip.h>

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace fletch {

struct Socket::SocketData {
  SocketData() : socket(INVALID_SOCKET), port(-1) { }
  SocketData(SOCKET socket, int port) : socket(socket), port(port) { }

  SOCKET socket;
  int port;
};

Socket::Socket() : data_(new SocketData()) {
  data_->socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (data_->socket == INVALID_SOCKET) FATAL("Failed socket creation.");
  BOOL optval = 1;
  int status = setsockopt(data_->socket, SOL_SOCKET, SO_REUSEADDR,
                          reinterpret_cast<char*>(&optval), sizeof(optval));
  if (status == SOCKET_ERROR) FATAL("Failed setting socket options.");
}

Socket* Socket::FromFd(int id) {
  UNIMPLEMENTED();
  return NULL;
}

Socket::Socket(SocketData* data) : data_(data) {
}

Socket::~Socket() {
  if (data_->socket != NULL) closesocket(data_->socket);
  delete data_;
}

static struct sockaddr LookupAddress(const char* host, int port) {
  struct addrinfo hints;
  ZeroMemory(&hints, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_ADDRCONFIG;
  hints.ai_protocol = IPPROTO_TCP;
  struct addrinfo* info = NULL;
  int status = getaddrinfo(host, 0, &hints, &info);
  if (status != 0) {
    // We failed, try without AI_ADDRCONFIG. This can happen when looking up
    // e.g. '::1', when there are no global IPv6 addresses.
    hints.ai_flags = 0;
    status = getaddrinfo(host, 0, &hints, &info);
  }
  ASSERT(status == 0);
  for (struct addrinfo* c = info; c != NULL; c = c->ai_next) {
    if (c->ai_family == AF_INET) {
      reinterpret_cast<struct sockaddr_in*>(c->ai_addr)->sin_port = htons(port);
      struct sockaddr addr = *reinterpret_cast<struct sockaddr*>(c->ai_addr);
      freeaddrinfo(info);
      return addr;
    }
  }
  UNREACHABLE();
  return sockaddr();
}

bool Socket::Connect(const char* host, int port) {
  struct sockaddr addr = LookupAddress(host, port);
  int status = connect(data_->socket, &addr, sizeof(struct sockaddr_in));
  return status == 0;
}

void Socket::Bind(const char* host, int port) {
  struct sockaddr addr = LookupAddress(host, port);
  int status = bind(data_->socket, &addr, sizeof(struct sockaddr_in));
  if (status == -1) FATAL("Failed Socket::Bind.");
}

int Socket::Listen() {
  int status = listen(data_->socket, SOMAXCONN);
  ASSERT(status == 0);
  struct sockaddr_in addr;
  socklen_t len = sizeof(addr);
  status = getsockname(data_->socket,
                       reinterpret_cast<struct sockaddr*>(&addr),
                       &len);
  if (status == -1) FATAL("Failed Socket::Listen.");
  return ntohs(addr.sin_port);
}

Socket* Socket::Accept() {
  struct sockaddr clientaddr;
  socklen_t addrlen = sizeof(clientaddr);
  while (true) {
    SOCKET socket = accept(data_->socket, &clientaddr, &addrlen);
    if (socket != INVALID_SOCKET) {
      Socket* child = new Socket(new SocketData(socket, data_->port));
      return child;
    } else {
      int error = WSAGetLastError();
      if (error == WSAECONNRESET ||
          error == WSAEINTR ||
          error == WSAEMFILE ||
          error == WSAENETDOWN ||
          error == WSAENOBUFS) {
        continue;
      }
      UNREACHABLE();
    }
  }
  return NULL;
}

void Socket::Write(uint8* data, int length) {
  int offset = 0;
  while (offset < length) {
    int bytes = send(data_->socket, reinterpret_cast<char*>(data) + offset,
                     length - offset, 0);
    if (bytes == SOCKET_ERROR) {
      FATAL1("Failed to write to socket: %p\n", data_->socket);
    }
    offset += bytes;
  }
}

uint8* Socket::Read(int length) {
  char* data = static_cast<char*>(malloc(length));
  int offset = 0;
  while (offset < length) {
    int bytes = recv(data_->socket, data + offset, length - offset, 0);
    if (bytes == SOCKET_ERROR) {
      Print::Error("Failed to read from socket\n");
      free(data);
      return NULL;
    }
    offset += bytes;
  }
  return reinterpret_cast<uint8*>(data);
}

int Socket::FileDescriptor() {
  UNIMPLEMENTED();
  return -1;
}

void Socket::SetTCPNoDelay(bool value) {
  BOOL option = value ? 1 : 0;
  int status = setsockopt(data_->socket, IPPROTO_TCP, TCP_NODELAY,
                          reinterpret_cast<char*>(&option), sizeof(option));
  if (status == SOCKET_ERROR) {
    Print::Error("Failed setting TCP_NODELAY socket options [%d]",
                 WSAGetLastError());
  }
}

}  // namespace fletch

#endif  // def'd(FLETCH_TARGET_OS_WIN) && def'd(FLETCH_ENABLE_LIVE_CODING)
