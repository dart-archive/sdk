// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/intrinsics.h"

namespace fletch {

#define DEFINE_INTRINSIC(name) \
  void Intrinsic_##name() { }
INTRINSICS_DO(DEFINE_INTRINSIC)
#undef DEFINE_INTRINSIC

}  // namespace fletch
