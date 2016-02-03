// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_ARM) && defined(DARTINO_TARGET_OS_MACOS)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace dartino {

#if defined(DARTINO_TARGET_ANDROID)
static const char* kPrefix = "";
#else
static const char* kPrefix = "_";
#endif

void Assembler::Bind(const char* prefix, const char* name) {
  putchar('\n');
  printf("\t.code 32\n");
  printf("\t.global %s%s%s\n", kPrefix, prefix, name);
  printf("%s%s%s:\n", kPrefix, prefix, name);
}

void Assembler::DefineLong(const char* name) {
  printf("\t.long %s%s\n", kPrefix, name);
}

const char* Assembler::LabelPrefix() { return kPrefix; }

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_ARM) && defined(DARTINO_TARGET_OS_MACOS)
