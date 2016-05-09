// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef INCLUDE_SOCKET_CONNECTION_API_H_
#define INCLUDE_SOCKET_CONNECTION_API_H_

#include "include/dartino_api.h"

typedef void* DartinoSocketConnectionListener;

// Allocates and binds a DartinoSocketListener with the given port. If port
// is 0, a free system port will be chosen.
DartinoSocketConnectionListener DartinoCreateSocketConnectionListener(
    const char* host, int port);

// Returns the port that this listener is bound to.
int DartinoSocketConnectionListenerPort(
    DartinoSocketConnectionListener listener);

// Waits for a connection.
DartinoConnection DartinoSocketConnectionListenerAccept(
    DartinoSocketConnectionListener listener);

// Deallocates the listener.
void DartinoDeleteSocketConnectionListener(
    DartinoSocketConnectionListener listener);

#endif  // INCLUDE_SOCKET_CONNECTION_API_H_
