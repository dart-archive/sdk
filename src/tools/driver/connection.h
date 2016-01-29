// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
  // If you modify this enum, please update
  // pkg/fletchc/lib/src/driver/driver_commands.dart as well.
  enum Command {
    kStdin,             // Data on stdin.
    kStdout,            // Data on stdout.
    kStderr,            // Data on stderr.
    kArguments,         // Command-line arguments.
    kSignal,            // Unix process signal received.
    kExitCode,          // Set process exit code.
    kEventLoopStarted,  // Not used.
    kClosePort,         // Not used.
    kSendPort,          // Not used.
    kPerformTask,       // Not used.

    kDriverConnectionError,   // Error in connection.
    kDriverConnectionClosed,  // Connection closed.
  };

  // Four bytes package length and one byte Command code.
  static const size_t kHeaderSize = 5;

  explicit DriverConnection(Socket* socket);

  virtual ~DriverConnection();

  int ReadInt() { return incoming_.ReadInt(); }
  int64 ReadInt64() { return incoming_.ReadInt64(); }
  double ReadDouble() { return incoming_.ReadDouble(); }
  bool ReadBoolean() { return incoming_.ReadBoolean(); }
  uint8* ReadBytes(int* length) { return incoming_.ReadBytes(length); }

  void Send(Command command, const WriteBuffer& buffer);
  Command Receive();

 private:
  Socket* socket_;
  ReadBuffer incoming_;
};

}  // namespace fletch

#endif  // SRC_TOOLS_DRIVER_CONNECTION_H_
