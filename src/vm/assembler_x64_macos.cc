// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_X64) && defined(FLETCH_TARGET_OS_MACOS)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::Bind(const char* prefix, const char* name) {
  putchar('\n');
  printf("\t.text\n");
  printf("\t.globl _%s%s\n", prefix, name);
  printf("_%s%s:\n", prefix, name);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_X64) && defined(FLETCH_TARGET_OS_MACOS)
