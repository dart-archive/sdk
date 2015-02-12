// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_IA32)

#include "src/vm/assembler.h"
#include "src/vm/generator.h"
#include "src/vm/object.h"

#define __ assembler->

namespace fletch {

GENERATE_NATIVE(SmiNegate) {
  __ movl(ECX, Address(ESP, 2 * kWordSize));
  __ movl(EAX, Address(ECX, 0 * kWordSize));
  __ negl(EAX);
  __ andl(EAX, Immediate(~Smi::kTagMask));
  __ ret();
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_IA32
