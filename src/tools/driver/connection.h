// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_TOOLS_DRIVER_CONNECTION_H_
#define SRC_TOOLS_DRIVER_CONNECTION_H_

#include "src/shared/globals.h"

#include "src/shared/connection.h"

namespace fletch {

class Socket;

class DriverConnection {
 public:
  enum Command {
    kStdin,  // Data on stdin.
    kStdout,  // Data on stdout.
    kStderr,  // Data on stderr.
    kArguments,  // Command-line arguments.
    kSignal,  // Unix process signal received.
    kExitCode,  // Set process exit code.

    kDriverConnectionError,  // Error in connection.
    kDriverConnectionClosed,  // Connection closed.
  };

  static const size_t kHeaderSize = 5;

  explicit DriverConnection(Socket* socket);

  virtual ~DriverConnection();

  int ReadInt() { return incoming_.ReadInt(); }
  int64 ReadInt64() { return incoming_.ReadInt64(); }
  double ReadDouble() { return incoming_.ReadDouble(); }
  bool ReadBoolean() { return incoming_.ReadBoolean(); }
  uint8* ReadBytes(int* length) { return incoming_.ReadBytes(length); }

  void WriteInt(int value) { outgoing_.WriteInt(value); }
  void WriteInt64(int64 value) { outgoing_.WriteInt64(value); }
  void WriteDouble(double value) { outgoing_.WriteDouble(value); }
  void WriteBoolean(bool value) { outgoing_.WriteBoolean(value); }
  void WriteBytes(const uint8* bytes, int length) {
    outgoing_.WriteBytes(bytes, length);
  }
  void WriteString(const char* str) { outgoing_.WriteString(str); }

  void Send(Command command);
  Command Receive();

 private:
  Socket* socket_;
  ReadBuffer incoming_;
  WriteBuffer outgoing_;
};

}  // namespace fletch

#endif  // SRC_TOOLS_DRIVER_CONNECTION_H_
