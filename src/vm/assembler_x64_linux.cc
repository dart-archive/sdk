// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_X64) && defined(FLETCH_TARGET_OS_LINUX)

#include <stdio.h>
#include "src/vm/assembler.h"

namespace fletch {

void Assembler::Bind(const char* prefix, const char* name) {
  printf("\t.global %s%s\n", prefix, name);
  printf("%s%s:\n", prefix, name);
}

void Assembler::LocalBind(const char* name) {
  printf("%s:\n", name);
}

void Assembler::RelativeDefine(const char* name,
                               const char* target,
                               const char* base) {
  printf("\n%s = %s-%s", name, target, base);
}

void Assembler::call(const char* name) { printf("\tcall %s@PLT\n", name); }

void Assembler::j(Condition condition, const char* name) {
  const char* mnemonic = ConditionMnemonic(condition);
  printf("\tj%s %s@PLT\n", mnemonic, name);
}

void Assembler::jmp(const char* name) {
  printf("\tjmp %s@PLT\n", name);
}

void Assembler::jmp(const char* name,
                    Register index,
                    ScaleFactor scale,
                    Register scratch) {
  // To make it PIC, the addresses in Interpret_DispatchTable are relative to
  // Interpret. Load the value, add the absolute position of Interpret, and
  // then jump to that address.
  // TODO(ajohnsen): Should we patch the dispatch table at startup instead?
  Print("leaq %s(%rq), %rq", name, RIP, scratch);
  Print("movq (%rq, %rq, %d), %rq", scratch, index, 1 << scale, scratch);
  Print("leaq LocalInterpret(%rq), %rq", RIP, index);
  Print("addq %rq, %rq", index, scratch);
  Print("jmpq *%rq", scratch);
}

void Assembler::DefineLong(const char* name) { printf("\t.quad %s\n", name); }

void Assembler::LoadNative(Register destination, Register index) {
  ASSERT(destination != index);
  Print("leaq kNativeTable(%%rip), %rq", destination);
  Print("movq (%rq,%rq,8), %rq", destination, index, destination);
}

void Assembler::LoadLabel(Register reg, const char* name) {
  Print("leaq %s(%%rip), %rq", name, reg);
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_X64) && defined(FLETCH_TARGET_OS_LINUX)
