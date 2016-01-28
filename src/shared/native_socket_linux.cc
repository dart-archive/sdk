// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX) && defined(FLETCH_ENABLE_LIVE_CODING)

#include "src/shared/native_socket.h"

#include <errno.h>

namespace fletch {

bool Socket::ShouldRetryAccept(int error) {
  return (error == EAGAIN) || (error == ENETDOWN) || (error == EPROTO) ||
         (error == ENOPROTOOPT) || (error == EHOSTDOWN) || (error == ENONET) ||
         (error == EHOSTUNREACH) || (error == EOPNOTSUPP) ||
         (error == ENETUNREACH);
}

}  // namespace fletch

#endif  // def'd(FLETCH_TARGET_OS_LINUX) && def'd(FLETCH_ENABLE_LIVE_CODING)
