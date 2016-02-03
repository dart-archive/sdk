// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_MACOS) && defined(DARTINO_ENABLE_LIVE_CODING)

#include "src/shared/native_socket.h"

namespace dartino {

bool Socket::ShouldRetryAccept(int error) { return false; }

}  // namespace dartino

#endif  // def'd(DARTINO_TARGET_OS_MACOS) && def'd(DARTINO_ENABLE_LIVE_CODING)
