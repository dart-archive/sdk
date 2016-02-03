// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_ARM64) && defined(DARTINO_TARGET_OS_LINUX)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace dartino {

void Assembler::Bind(const char* prefix, const char* name) { UNIMPLEMENTED(); }

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_ARM64) && defined(DARTINO_TARGET_OS_LINUX)
