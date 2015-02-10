// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_IA32)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::call(const char* name) {
  printf("\tcall %s\n", name);
}

void Assembler::j(Condition condition, const char* name) {
  const char* mnemonic = ConditionMnemonic(condition);
  printf("\tj%s %s\n", mnemonic, name);
}

void Assembler::jmp(const char* name) {
  printf("\tjmp %s\n", name);
}

void Assembler::Bind(const char* name) {
  printf("\n\t.text\n\t.align 16,0x90\n\t.global %s\n%s:\n", name, name);
}

void Assembler::DefineLong(const char* name) {
  printf("\t.long %s\n", name);
}

void Assembler::LoadNative(Register reg, Register index) {
  Print("movl kNativeTable(,%rl,4), %rl", index, reg);
}

}  // namespace fletch

#endif  // defined(FLETCH_IA32)
