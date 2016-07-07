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

#ifdef DARTINO_TARGET_ARM_HARDFLOAT

// Generate code to load a pair of floating point registers
// num is 0-7 corresponding to one of d0-d7 or two of s0-s15
// base is a pointer to an array of floating point arguments
static void FloatingPointPair(Assembler* assembler, Register base, int num) {
  __ vldr(Register(S1 + num * 2), base, Immediate(kWordSize * (num * 2 + 1)));
  __ vldr(Register(S0 + num * 2), base, Immediate(kWordSize * num * 2));
}

#endif  // DARTINO_TARGET_ARM_HARDFLOAT

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
  Label noVfp, vfp2, vfp4, vfp6, vfp8, vfp10, vfp12, vfp14,
  double7, double6, double5, double4, double3, double2, double1, double0;
  // Deal with VFP arguments first.
  __ ldr(R6, SP, Immediate((kCalleeSaved + 1) * kWordSize));
  __ cmp(R6, Immediate(0));
  __ b(EQ, &noVfp);
  __ ldr(R5, SP, Immediate(kCalleeSaved * kWordSize));
  // TODO(dmitryolsh): should be possible to construct jump table.
  __ cmp(R6, Immediate(2));
  __ b(EQ, &vfp2);
  __ cmp(R6, Immediate(4));
  __ b(EQ, &vfp4);
  __ cmp(R6, Immediate(6));
  __ b(EQ, &vfp6);
  __ cmp(R6, Immediate(8));
  __ b(EQ, &vfp8);
  __ cmp(R6, Immediate(10));
  __ b(EQ, &vfp10);
  __ cmp(R6, Immediate(12));
  __ b(EQ, &vfp12);
  __ cmp(R6, Immediate(14));
  __ b(EQ, &vfp14);
  // Fall-through on 16.

  FloatingPointPair(assembler, R5, 7);
  __ Bind(&vfp14);
  FloatingPointPair(assembler, R5, 6);
  __ Bind(&vfp12);
  FloatingPointPair(assembler, R5, 5);
  __ Bind(&vfp10);
  FloatingPointPair(assembler, R5, 4);
  __ Bind(&vfp8);
  FloatingPointPair(assembler, R5, 3);
  __ Bind(&vfp6);
  FloatingPointPair(assembler, R5, 2);
  __ Bind(&vfp4);
  FloatingPointPair(assembler, R5, 1);
  __ Bind(&vfp2);
  FloatingPointPair(assembler, R5, 0);
  __ Bind(&noVfp);
#endif  // DARTINO_TARGET_ARM_HARDFLOAT

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
