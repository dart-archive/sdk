// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_IA32) && defined(FLETCH_TARGET_OS_MACOS)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::call(const char* name) {
  printf("\tcall _%s\n", name);
}

void Assembler::j(Condition condition, const char* name) {
  const char* mnemonic = ConditionMnemonic(condition);
  printf("\tj%s _%s\n", mnemonic, name);
}

void Assembler::jmp(const char* name) {
  printf("\tjmp _%s\n", name);
}

void Assembler::Bind(const char* name) {
  putchar('\n');
  printf("\t.text\n");
  AlignToPowerOfTwo(4);
  printf("\t.globl _%s\n", name);
  printf("_%s:\n", name);
}

void Assembler::DefineLong(const char* name) {
  printf("\t.long _%s\n", name);
}

void Assembler::LoadNative(Register reg, Register index) {
  Print("movl _kNativeTable(,%rl,4), %rl", index, reg);
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_IA32 && defined(FLETCH_TARGET_OS_MACOS)
