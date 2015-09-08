// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef FLETCH_ENABLE_FFI

#include "src/vm/natives.h"
#include "src/shared/assert.h"

namespace fletch {

NATIVE(NativeProcessSpawnDetached) {
  UNIMPLEMENTED();
  return NULL;
}

}  // namespace fletch

#endif  // !FLETCH_ENABLE_FFI
