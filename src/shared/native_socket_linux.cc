// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/native_socket.h"

#include <errno.h>

namespace fletch {

bool Socket::ShouldRetryAccept(int error) {
  return (error == EAGAIN) || (error == ENETDOWN) || (error == EPROTO) ||
         (error == ENOPROTOOPT) || (error == EHOSTDOWN) || (error == ENONET) ||
         (error == EHOSTUNREACH) || (error == EOPNOTSUPP) ||
         (error == ENETUNREACH);
}

}
