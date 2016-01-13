// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_IA32) && defined(FLETCH_TARGET_OS_LINUX)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::call(const char* name) { printf("\tcall %s\n", name); }

void Assembler::j(Condition condition, const char* name) {
  const char* mnemonic = ConditionMnemonic(condition);
  printf("\tj%s %s\n", mnemonic, name);
}

void Assembler::jmp(const char* name) { printf("\tjmp %s\n", name); }

void Assembler::jmp(const char* name, Register index, ScaleFactor scale) {
  Print("jmp *%s(,%rl,%d)", name, index, 1 << scale);
}

void Assembler::Bind(const char* prefix, const char* name) {
  printf("\t.global %s%s\n", prefix, name);
  printf("%s%s:\n", prefix, name);
}

void Assembler::DefineLong(const char* name) { printf("\t.long %s\n", name); }

void Assembler::LoadNative(Register destination, Register index) {
  Print("movl kNativeTable(,%rl,4), %rl", index, destination);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_IA32) && defined(FLETCH_TARGET_OS_LINUX)
