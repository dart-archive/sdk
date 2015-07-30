// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_MACOS)

#include "src/shared/native_socket.h"

namespace fletch {

bool Socket::ShouldRetryAccept(int error) {
  return false;
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_MACOS)
