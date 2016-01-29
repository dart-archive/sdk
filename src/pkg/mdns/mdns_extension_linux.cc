// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "include/dart_api.h"
#include "include/dart_native_api.h"

#include "mdns_extension.h"

// Dummy implementation for Linux.
void HandleLookup(Dart_Port port_id, int type, char* fullname, int timeout) {}

#endif
