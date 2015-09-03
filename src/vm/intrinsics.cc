// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if !defined(FLETCH_TARGET_IA32) && !defined(FLETCH_TARGET_ARM)

#include "src/vm/intrinsics.h"

#include "src/shared/assert.h"

namespace fletch {

#define DEFINE_INTRINSIC(name) \
  void __attribute__((aligned(4))) Intrinsic_##name() { UNREACHABLE(); }
INTRINSICS_DO(DEFINE_INTRINSIC)
#undef DEFINE_INTRINSIC

}  // namespace fletch

#endif  // !defined(FLETCH_TARGET_IA32) && !defined(FLETCH_TARGET_ARM)
