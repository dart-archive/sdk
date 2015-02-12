// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_ARM)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::Bind(const char* name) {
  printf("\n\t.text\n\t.align 16,0x90\n\t.global %s\n%s:\n", name, name);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_ARM)
