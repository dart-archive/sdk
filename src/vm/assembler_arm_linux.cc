// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_ARM) && defined(DARTINO_TARGET_OS_LINUX) && \
    !defined(DARTINO_THUMB_ONLY)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace dartino {

void Assembler::Bind(const char* prefix, const char* name) {
  putchar('\n');
  printf("\t.type %s%s, %%function\n", prefix, name);
  printf("\t.code 32\n");
  printf("\t.global %s%s\n%s%s:\n", prefix, name, prefix, name);
}

void Assembler::DefineLong(const char* name) { printf("\t.long %s\n", name); }

const char* Assembler::LabelPrefix() { return ""; }

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_ARM) && defined(DARTINO_TARGET_OS_LINUX) &&
        // !defined(DARTINO_THUMB_ONLY)
