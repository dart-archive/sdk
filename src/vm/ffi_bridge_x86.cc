// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_IA32)

#include "src/vm/assembler.h"
#include "src/vm/generator.h"

#define __ assembler->

namespace dartino {

GENERATE(, FfiBridge) {
  Label copyLoop, outOfLoop;
  // [ESP] - stack, [ESP+4] - length
  // [ESP+8] - function pointer
  __ pushl(ESI);
  __ pushl(EDI);
  __ pushl(EBX);
  const int kCalleeSaved = 4*kWordSize;  // 3 registers + return address.
  __ movl(EAX, ESP, Immediate(kCalleeSaved));
  __ movl(ECX, ESP, Immediate(kCalleeSaved + kWordSize));
  __ movl(EDX, ESP, Immediate(kCalleeSaved + 2*kWordSize));
  // Allocate the stack space.
  __ movl(EDI, ECX);
  __ shll(EDI, Immediate(kWordSizeLog2));
  __ subl(ESP, EDI);
  // Copy arguments to the stack.
  __ cmpl(ECX, Immediate(0));
  __ j(EQUAL, &outOfLoop);
  __ movl(ESI, ESP);
  __ Bind(&copyLoop);
  __ movl(EBX, EAX, Immediate(0));
  __ movl(ESI, Immediate(0), EBX);
  __ addl(ESI, Immediate(kWordSize));
  __ addl(EAX, Immediate(kWordSize));
  __ subl(ECX, Immediate(1));
  __ j(NOT_ZERO, &copyLoop);
  __ Bind(&outOfLoop);
  // Call the pointer.
  __ call(EDX);

  // Restore the stack.
  __ addl(ESP, EDI);
  __ popl(EBX);
  __ popl(EDI);
  __ popl(ESI);
  __ ret();
}

}  // namespace dartino

#endif
