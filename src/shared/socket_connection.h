// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_SOCKET_CONNECTION_H_
#define SRC_SHARED_SOCKET_CONNECTION_H_

#include "src/shared/connection.h"

namespace dartino {

class SocketConnection : public Connection {
 public:
  static SocketConnection* Connect(const char* host, int port);
  ~SocketConnection();
  void Send(Opcode opcode, const WriteBuffer& buffer);
  Connection::Opcode Receive();

 private:
  Socket* socket_;

  friend class ConnectionListener;
  SocketConnection(const char* host, int port, Socket* socket);
};

class ConnectionListener {
 public:
  ConnectionListener(const char* host, int port);
  virtual ~ConnectionListener();

  int Port();

  Connection* Accept();

 private:
  Socket* socket_;
  int port_;
};

}  // namespace dartino

#endif  // SRC_SHARED_SOCKET_CONNECTION_H_
