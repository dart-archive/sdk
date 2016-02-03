// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include "src/vm/vector.h"

namespace dartino {

uint8* DoubleSize(size_t capacity, uint8* backing) {
  uint8* new_backing = new uint8[capacity * 2];
  memcpy(new_backing, backing, capacity);
#ifdef DEBUG
  memset(backing, 0xdd, capacity);
#endif
  delete[] backing;
  return new_backing;
}

}  // namespace dartino
