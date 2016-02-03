// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_TOOLS_DRIVER_PLATFORM_H_
#define SRC_TOOLS_DRIVER_PLATFORM_H_

namespace dartino {

// Create a file descriptor from which signals can be read. The file descriptor
// can be used with select, and signal numbers can be read using 'ReadSignal'.
int SignalFileDescriptor();

// Read a signal from a file descriptor created with 'SignalFileDescriptor'.
int ReadSignal(int fd);

// Exit in a platform specific manner. 'exit_code' is encoded as
// 'Process.exitCode' in 'dart:io'.
void Exit(int exit_code);

}  // namespace dartino

#endif  // SRC_TOOLS_DRIVER_PLATFORM_H_
