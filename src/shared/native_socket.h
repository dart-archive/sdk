// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVE_SOCKET_H_
#define SRC_SHARED_NATIVE_SOCKET_H_

#ifndef FLETCH_ENABLE_LIVE_CODING
#error "native_socket.h is only available when live coding is enabled."
#endif

#include "src/shared/globals.h"

namespace fletch {

class Socket {
 public:
  Socket();
  explicit Socket(int fd);
  virtual ~Socket();

  bool Connect(const char* host, int port);

  void Bind(const char* host, int port);

  // Returns the port the socket is listening on.
  int Listen();

  Socket* Accept();

  void Write(uint8* data, int length);
  uint8* Read(int length);

  int FileDescriptor();

  void SetTCPNoDelay(bool value);

 private:
  bool ShouldRetryAccept(int error);

  struct SocketData;
  SocketData* data_;
};

}  // namespace fletch

#endif  // SRC_SHARED_NATIVE_SOCKET_H_
