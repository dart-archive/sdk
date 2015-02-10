// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_X64)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::Bind(const char* name) {
  printf("\n\t.text\n\t.align 4,0x90\n.globl _%s\n_%s:\n", name, name);
}

}  // namespace fletch

#endif  // defined FLETCH_X64
