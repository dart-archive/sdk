// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_OS_H_
#define SRC_COMPILER_OS_H_

#include "src/shared/globals.h"
#include "src/compiler/list.h"

namespace fletch {

class Zone;

class OS {
 public:
  static int64 CurrentTime();

  // Resolve 'path' relative to 'uri'.
  // If 'zone' is NULL, malloc is used for allocating the buffer.
  static const char* UriResolve(const char* uri, const char* path, Zone* zone);

  // Load file at 'uri'. The returned buffer is '0' terminated.
  // If 'zone' is NULL, malloc is used for allocating the buffer.
  static char* LoadFile(const char* uri,
                        Zone* zone,
                        uint32* file_size = NULL);

  // Store file at 'uri'.
  static bool StoreFile(const char* uri, List<uint8> bytes);
};

}  // namespace fletch

#endif  // SRC_COMPILER_OS_H_
