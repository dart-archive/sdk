// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/socket_connection_api_impl.h"

#include "src/shared/socket_connection.h"

DartinoSocketConnectionListener DartinoCreateSocketConnectionListener(
    const char* host, int port) {
  return reinterpret_cast<DartinoSocketConnectionListener>(
      new dartino::ConnectionListener(host, port));
}

int DartinoSocketConnectionListenerPort(
    DartinoSocketConnectionListener listener) {
  return reinterpret_cast<dartino::ConnectionListener*>(listener)->Port();
}

DartinoConnection DartinoSocketConnectionListenerAccept(
      DartinoSocketConnectionListener listener) {
  return reinterpret_cast<DartinoConnection>(
    reinterpret_cast<dartino::ConnectionListener*>(listener)->Accept());
}

void DartinoDeleteSocketConnectionListener(
    DartinoSocketConnectionListener listener) {
  delete reinterpret_cast<dartino::ConnectionListener*>(listener);
}
