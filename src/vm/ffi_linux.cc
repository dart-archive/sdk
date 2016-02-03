// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LINUX)

#ifdef DARTINO_ENABLE_FFI

#include "src/vm/ffi.h"

namespace dartino {

const char* ForeignUtils::kLibBundlePrefix = "/lib/lib";
const char* ForeignUtils::kLibBundlePostfix = ".so";

}  // namespace dartino

#endif  // DARTINO_ENABLE_FFI

#endif  // defined(DARTINO_TARGET_OS_LINUX)
