// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LINUX)

#include "src/vm/ffi.h"

namespace fletch {

const char* ForeignUtils::kLibBundlePrefix = "/lib/lib";
const char* ForeignUtils::kLibBundlePostfix = ".so";

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_LINUX)
