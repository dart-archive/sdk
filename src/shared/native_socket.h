// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVE_SOCKET_H_
#define SRC_SHARED_NATIVE_SOCKET_H_

#include "src/shared/globals.h"

namespace dartino {

class Socket {
 public:
  Socket();

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

  static Socket* FromFd(int fd);

 private:
  struct SocketData;

  explicit Socket(SocketData* data);

  bool ShouldRetryAccept(int error);

  SocketData* data_;
};

}  // namespace dartino

#endif  // SRC_SHARED_NATIVE_SOCKET_H_
