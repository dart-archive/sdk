// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_X64)

#include "src/vm/assembler.h"
#include "src/vm/generator.h"

#define __ assembler->

namespace dartino {

void loadSSE(Assembler* assembler, Register from, int n, Register flags) {
  Label doubleSized, end;
  __ testl(flags, Immediate(1 << n));
  __ j(NOT_ZERO, &doubleSized);
  __ movss(Register(XMM0 + n), from, Immediate(kWordSize * n));
  __ jmp(&end);
  __ Bind(&doubleSized);
  __ movsd(Register(XMM0 + n), from, Immediate(kWordSize * n));
  __ Bind(&end);
}

GENERATE(, FfiBridge) {
  Label fpArgument0, fpArgument1, fpArgument2, fpArgument3, fpArgument4,
    fpArgument5, fpArgument6, noFpArguments;
  Label copyStack, noStack, noRegisters, register0, register1, register2,
    register3, register4, register5;
  // Arguments:
  // (RDI, RSI) - register parameters
  // (RDX, RCX) - stack parameters
  // (R8, R9) - floating point parameters
  // [RSP+8], [RSP+16] - function pointer, floating point flags
  __ pushq(RBX);
  __ pushq(R12);
  const int kCalleeSaved = 3*kWordSize;  // 2 registers + return address
  __ movq(RAX, RSP, Immediate(kCalleeSaved));
  __ movq(RBX, RSP, Immediate(kCalleeSaved+kWordSize));
  // Load XMM registers.
  __ cmpl(R9, Immediate(0));
  __ j(EQUAL, &noFpArguments);
  __ cmpl(R9, Immediate(1));
  __ j(EQUAL, &fpArgument0);
  __ cmpl(R9, Immediate(2));
  __ j(EQUAL, &fpArgument1);
  __ cmpl(R9, Immediate(3));
  __ j(EQUAL, &fpArgument2);
  __ cmpl(R9, Immediate(4));
  __ j(EQUAL, &fpArgument3);
  __ cmpl(R9, Immediate(5));
  __ j(EQUAL, &fpArgument4);
  __ cmpl(R9, Immediate(6));
  __ j(EQUAL, &fpArgument5);
  __ cmpl(R9, Immediate(7));
  __ j(EQUAL, &fpArgument6);
  // Fallthrough on == 8.

  loadSSE(assembler, R8, 7, RBX);
  __ Bind(&fpArgument6);
  loadSSE(assembler, R8, 6, RBX);
  __ Bind(&fpArgument5);
  loadSSE(assembler, R8, 5, RBX);
  __ Bind(&fpArgument4);
  loadSSE(assembler, R8, 4, RBX);
  __ Bind(&fpArgument3);
  loadSSE(assembler, R8, 3, RBX);
  __ Bind(&fpArgument2);
  loadSSE(assembler, R8, 2, RBX);
  __ Bind(&fpArgument1);
  loadSSE(assembler, R8, 1, RBX);
  __ Bind(&fpArgument0);
  loadSSE(assembler, R8, 0, RBX);
  __ Bind(&noFpArguments);

  // Allocate the stack and round up to 16 bytes.
  // R12 = (RCX * kWordSize + kWordSize) & ~(2 * kWordSize)
  __ movq(R12, RCX);
  __ shlq(R12, Immediate(kWordSizeLog2));
  __ addq(R12, Immediate(kWordSize));
  __ andq(R12, Immediate(~(2*kWordSize)));
  __ subq(RSP, R12);
  __ cmpl(RCX, Immediate(0));
  __ j(EQUAL, &noStack);
  // Copy stack arguments.
  __ movq(RBX, RSP);
  __ Bind(&copyStack);
  __ movq(R10, RDX, Immediate(0));
  __ movq(RBX, Immediate(0), R10);
  __ addq(RDX, Immediate(kWordSize));
  __ addq(RBX, Immediate(kWordSize));
  __ subq(RCX, Immediate(1));
  __ j(NOT_EQUAL, &copyStack);
  __ Bind(&noStack);

  // Fill in register arguments.
  __ movq(RBX, RDI);
  __ cmpl(RSI, Immediate(0));
  __ j(EQUAL, &noRegisters);
  __ cmpl(RSI, Immediate(1));
  __ j(EQUAL, &register0);
  __ cmpl(RSI, Immediate(2));
  __ j(EQUAL, &register1);
  __ cmpl(RSI, Immediate(3));
  __ j(EQUAL, &register2);
  __ cmpl(RSI, Immediate(4));
  __ j(EQUAL, &register3);
  __ cmpl(RSI, Immediate(5));
  __ j(EQUAL, &register4);
  // Fallthrough on == 6
  __ movq(R9, RBX, Immediate(5*kWordSize));
  __ Bind(&register4);
  __ movq(R8, RBX, Immediate(4*kWordSize));
  __ Bind(&register3);
  __ movq(RCX, RBX, Immediate(3*kWordSize));
  __ Bind(&register2);
  __ movq(RDX, RBX, Immediate(2*kWordSize));
  __ Bind(&register1);
  __ movq(RSI, RBX, Immediate(kWordSize));
  __ Bind(&register0);
  __ movq(RDI, RBX, Immediate(0));
  __ Bind(&noRegisters);

  // Call the pointer.
  __ call(RAX);

  // Restore the stack.
  __ addq(RSP, R12);
  __ popq(R12);
  __ popq(RBX);
  __ ret();
}

}  // namespace dartino

#endif
