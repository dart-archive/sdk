// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef MDNS_EXTENSION_H_
#define MDNS_EXTENSION_H_

#include "include/dart_api.h"
#include "include/dart_native_api.h"

// Requests Ids. This should be aligned with the Dart code.
enum RequestType { kEchoRequest = 0, kLookupRequest = 1 };

void HandleEcho(Dart_Port reply_port, Dart_CObject* argument);
void HandleLookup(Dart_Port port_id, int type, char* fullname, int timeout);

#endif
