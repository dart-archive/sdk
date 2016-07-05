// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_ARM)

#include "src/vm/assembler.h"
#include "src/vm/generator.h"

#define __ assembler->

namespace dartino {

// TODO(dmitryolsh) : copy-pasted from interpreter_arm, consolidate it?
static RegisterList RegisterRange(Register first, Register last) {
  ASSERT(first <= last);
  RegisterList value = 0;
  for (int i = first; i <= last; i++) {
    value |= (1 << i);
  }
  return value;
}

GENERATE(, FfiBridge) {
  Label noargs, fitsInOne, fitsInTwo, fitsInThree, fitsInFour,
    skipRestoreStack, noStack, copyArgs;
  const int kCalleeSaved = 8;
  // Keep stack 8-byte aligned at all times, to follow the ABI requirements.
  ASSERT(kCalleeSaved % 2 == 0);
  const int kStackAlignment = 8;
  // R0,R1 - (pointer, length) regular register arguments.
  // R2,R3 - (pointer, length) stack arguments.
  // [SP], [SP+4] - (pointer,length) VFP register arguments.
  // [SP+8] - function to call.
  __ push(RegisterRange(R4, R10) | RegisterRange(LR, LR));

#ifdef DARTINO_TARGET_ARM_HARDFLOAT
  // VFP labels - for handling Vectorized Floating Point coprocessor registers.
  Label noVfp, vfp1, vfp2, vfp3, vfp4, vfp5, vfp6, vfp7, vfp8, vfp9, vfp10,
    vfp11, vfp12, vfp13, vfp14, vfp15, vfp16;
  // Deal with VFP arguments first.
  __ ldr(R6, SP, Immediate((kCalleeSaved + 1) * kWordSize));
  __ cmp(R6, Immediate(0));
  __ b(EQ, &noVfp);
  __ ldr(R5, SP, Immediate(kCalleeSaved * kWordSize));
  // TODO(dmitryolsh): should be possible to construct jump table.
  __ cmp(R6, Immediate(1));
  __ b(EQ, &vfp1);
  __ cmp(R6, Immediate(2));
  __ b(EQ, &vfp2);
  __ cmp(R6, Immediate(3));
  __ b(EQ, &vfp3);
  __ cmp(R6, Immediate(4));
  __ b(EQ, &vfp4);
  __ cmp(R6, Immediate(5));
  __ b(EQ, &vfp5);
  __ cmp(R6, Immediate(6));
  __ b(EQ, &vfp6);
  __ cmp(R6, Immediate(7));
  __ b(EQ, &vfp7);
  __ cmp(R6, Immediate(8));
  __ b(EQ, &vfp8);
  __ cmp(R6, Immediate(9));
  __ b(EQ, &vfp9);
  __ cmp(R6, Immediate(10));
  __ b(EQ, &vfp10);
  __ cmp(R6, Immediate(11));
  __ b(EQ, &vfp11);
  __ cmp(R6, Immediate(12));
  __ b(EQ, &vfp12);
  __ cmp(R6, Immediate(13));
  __ b(EQ, &vfp13);
  __ cmp(R6, Immediate(14));
  __ b(EQ, &vfp14);
  __ cmp(R6, Immediate(15));
  __ b(EQ, &vfp15);
  // Fall-through on 16.

  __ Bind(&vfp16);
  __ vldr(S15, R5, Immediate(kWordSize * 15));
  __ Bind(&vfp15);
  __ vldr(S14, R5, Immediate(kWordSize * 14));
  __ Bind(&vfp14);
  __ vldr(S13, R5, Immediate(kWordSize * 13));
  __ Bind(&vfp13);
  __ vldr(S12, R5, Immediate(kWordSize * 12));
  __ Bind(&vfp12);
  __ vldr(S11, R5, Immediate(kWordSize * 11));
  __ Bind(&vfp11);
  __ vldr(S10, R5, Immediate(kWordSize * 10));
  __ Bind(&vfp10);
  __ vldr(S9,  R5, Immediate(kWordSize * 9));
  __ Bind(&vfp9);
  __ vldr(S8,  R5, Immediate(kWordSize * 8));
  __ Bind(&vfp8);
  __ vldr(S7,  R5, Immediate(kWordSize * 7));
  __ Bind(&vfp7);
  __ vldr(S6,  R5, Immediate(kWordSize * 6));
  __ Bind(&vfp6);
  __ vldr(S5,  R5, Immediate(kWordSize * 5));
  __ Bind(&vfp5);
  __ vldr(S4,  R5, Immediate(kWordSize * 4));
  __ Bind(&vfp4);
  __ vldr(S3,  R5, Immediate(kWordSize * 3));
  __ Bind(&vfp3);
  __ vldr(S2,  R5, Immediate(kWordSize * 2));
  __ Bind(&vfp2);
  __ vldr(S1,  R5, Immediate(kWordSize));
  __ Bind(&vfp1);
  __ vldr(S0,  R5, Immediate(0));
  __ Bind(&noVfp);
#endif

  // R5 - function pointer.
  __ ldr(R5, SP, Immediate((kCalleeSaved + 2) * kWordSize));
  __ mov(R8, R2);
  __ mov(R9, R3);

  __ cmp(R9, Immediate(0));
  __ mov(R6, R0);
  __ mov(R7, R1);
  __ b(EQ, &noStack);
  // Calculate the stack space rounded up to 8-byte alignment.
  // (N*kWordSize + kWordSize) & ~(kStackAlignment-1)
  __ lsl(R4, R9, Immediate(kWordSizeLog2));
  __ add(R4, R4, Immediate(kWordSize));
  __ bic(R4, R4, Immediate(kStackAlignment - 1));
  __ sub(SP, SP, R4);

  // Copy stack arguments array (R8, R9) to the stack.
  __ mov(R3, SP);
  __ mov(R1, R9);
  __ Bind(&copyArgs);
  __ ldr_postinc(R4, R8, Immediate(4));
  __ str_postinc(R4, R3, Immediate(4));
  __ sub(R1, R1, Immediate(1));
  __ cmp(R1, Immediate(0));
  __ b(NE, &copyArgs);
  __ Bind(&noStack);

  // Copy core registers.
  __ cmp(R7, Immediate(4));
  __ b(EQ, &fitsInFour);
  __ cmp(R7, Immediate(3));
  __ b(EQ, &fitsInThree);
  __ cmp(R7, Immediate(2));
  __ b(EQ, &fitsInTwo);
  __ cmp(R7, Immediate(1));
  __ b(EQ, &fitsInOne);
  __ b(&noargs);

  __ Bind(&fitsInFour);
  __ ldr(R3, R6, Immediate(12));
  __ Bind(&fitsInThree);
  __ ldr(R2, R6, Immediate(8));
  __ Bind(&fitsInTwo);
  __ ldr(R1, R6, Immediate(4));
  __ Bind(&fitsInOne);
  __ ldr(R0, R6, Immediate(0));
  __ Bind(&noargs);
  __ blx(R5);

  // Check if we need to restore stack.
  __ cmp(R9, Immediate(0));
  __ b(EQ, &skipRestoreStack);

  // Calculate the stack space see above.
  __ lsl(R4, R9, Immediate(kWordSizeLog2));
  __ add(R4, R4, Immediate(kWordSize));
  __ bic(R4, R4, Immediate(kStackAlignment - 1));
  __ add(SP, SP, R4);

  __ Bind(&skipRestoreStack);
  __ pop(RegisterRange(R4, R10) | RegisterRange(PC, PC));
}

}  // namespace dartino

#endif
