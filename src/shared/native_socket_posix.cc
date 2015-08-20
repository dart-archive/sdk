// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX) && defined(FLETCH_ENABLE_LIVE_CODING)

#include "src/shared/native_socket.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace fletch {

struct Socket::SocketData {
  int fd;
};

Socket::Socket() : data_(new SocketData()) {
  data_->fd = socket(AF_INET, SOCK_STREAM, 0);
  if (data_->fd < 0) FATAL("Failed socket creation.");
  int status = fcntl(data_->fd, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making socket close on exec.");
  int optval = 1;
  status = setsockopt(data_->fd, SOL_SOCKET, SO_REUSEADDR,
                      &optval, sizeof(optval));
  if (status == -1) FATAL("Failed setting socket options.");
}

Socket::Socket(int fd) : data_(new SocketData()) {
  data_->fd = fd;
  ASSERT(data_->fd >= 0);
  int status = fcntl(data_->fd, FD_CLOEXEC);
  if (status == -1) FATAL("Failed making socket close on exec.");
}

Socket::~Socket() {
  TEMP_FAILURE_RETRY(close(data_->fd));
  delete data_;
}

static struct sockaddr LookupAddress(const char* host, int port) {
  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_flags = AI_ADDRCONFIG;
  hints.ai_protocol = IPPROTO_TCP;
  struct addrinfo* info = NULL;
  int status = getaddrinfo(host, 0, &hints, &info);
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
  int status = connect(data_->fd, &addr, sizeof(struct sockaddr_in));
  return status == 0;
}

void Socket::Bind(const char* host, int port) {
  struct sockaddr addr = LookupAddress(host, port);
  int status = bind(data_->fd, &addr, sizeof(struct sockaddr_in));
  if (status == -1) FATAL("Failed Socket::Bind.");
}

int Socket::Listen() {
  int status = listen(data_->fd, SOMAXCONN);
  ASSERT(status == 0);
  struct sockaddr_in addr;
  socklen_t len = sizeof(addr);
  status = getsockname(data_->fd,
                       reinterpret_cast<struct sockaddr*>(&addr),
                       &len);
  if (status == -1) FATAL("Failed Socket::Listen.");
  return ntohs(addr.sin_port);
}

Socket* Socket::Accept() {
  struct sockaddr clientaddr;
  socklen_t addrlen = sizeof(clientaddr);
  while (true) {
    int socket = TEMP_FAILURE_RETRY(accept(data_->fd, &clientaddr, &addrlen));
    if (socket >= 0) {
      Socket* child = new Socket();
      child->data_->fd = socket;
      return child;
    } else {
      int error = errno;
      if (ShouldRetryAccept(error)) continue;
      UNREACHABLE();
    }
  }
  UNIMPLEMENTED();
  return NULL;
}

void Socket::Write(uint8* data, int length) {
  int offset = 0;
  while (offset < length) {
    int bytes = TEMP_FAILURE_RETRY(
        write(data_->fd, data + offset, length - offset));
    if (bytes < 0) {
      Print::Error("Failed to write to socket: %i\n", data_->fd);
      UNREACHABLE();
    }
    offset += bytes;
  }
}

uint8* Socket::Read(int length) {
  uint8* data = static_cast<uint8*>(malloc(length));
  int offset = 0;
  while (offset < length) {
    int bytes = TEMP_FAILURE_RETRY(
        read(data_->fd, data + offset, length - offset));
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
  return data_->fd;
}

void Socket::SetTCPNoDelay(bool value) {
  int option = value ? 1 : 0;
  int status = setsockopt(data_->fd, IPPROTO_TCP, TCP_NODELAY,
                          &option, sizeof(option));
  if (status == -1) perror("Failed setting TCP_NODELAY socket options.");
}

}  // namespace fletch

#endif  // def'd(FLETCH_TARGET_OS_POSIX) && def'd(FLETCH_ENABLE_LIVE_CODING)
