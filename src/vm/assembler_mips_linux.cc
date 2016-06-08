// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_MIPS)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace dartino {

void Assembler::Bind(const char* prefix, const char* name) {
  putchar('\n');
  printf("\t.type %s%s, @function\n", prefix, name);
  printf("\t.globl %s%s\n%s%s:\n", prefix, name, prefix, name);
  printf("\n\t.set noreorder\n");
}

void Assembler::DefineLong(const char* name) {
  printf("\t.long %s\n", name);
}

const char* Assembler::LabelPrefix() { return ""; }

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_MIPS)
