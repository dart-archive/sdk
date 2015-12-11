// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/codegen.h"

#include "src/vm/assembler.h"
#include "src/vm/process.h"

#define __ assembler()->

namespace fletch {

void Codegen::DoEntry() {
  char name[256];
  sprintf(name, "Function_%p", function_);
  __ Bind(name);

  __ pushl(EBP);
  __ movl(EBP, ESP);
}

void Codegen::DoLoadLocal(int index) {
  __ pushl(Address(ESP, index * kWordSize));
}

void Codegen::DoStoreLocal(int index) {
  __ popl(Address(ESP, index * kWordSize));
}

void Codegen::DoLoadInteger(int value) {
  __ pushl(Immediate(reinterpret_cast<int32>(Smi::FromWord(value))));
}

void Codegen::DoLoadProgramRoot(int offset) {
  __ movl(EAX, Address(ESI, Process::kProgramOffset));
  __ pushl(Address(EAX, offset));
}

void Codegen::DoLoadProgramConstant(int index) {
  int offset = index * kWordSize + Array::kSize - HeapObject::kTag;
  __ movl(EAX, Address(ESI, Process::kProgramOffset));
  __ movl(EAX, Address(EAX, Program::kConstantsOffset));
  __ pushl(Address(EAX, offset));
}

void Codegen::DoInvokeMethod(int arity, int offset) {
  Label done;
  __ movl(EAX, Address(ESP, arity * kWordSize));
  __ movl(EDX, Immediate(program()->smi_class()->id()));  // Smi tag?
  __ testl(EAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &done);

  // TODO(kasperl): Use class id in objects? Less indirection.
  __ movl(EDX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movl(EDX, Address(EDX, Class::kIdOrTransformationTargetOffset - HeapObject::kTag));
  __ Bind(&done);

  __ movl(EAX, Address(EDI, EDX, TIMES_2, offset * kWordSize));
  __ cmpl(Address(EAX, 2 * kWordSize + Array::kSize - HeapObject::kTag), Immediate(offset));
  __ j(NOT_EQUAL, &done);

  __ call(Address(EAX, 3 * kWordSize + Array::kSize - HeapObject::kTag));
  DoDrop(arity);
  __ pushl(EAX);
}

void Codegen::DoDrop(int n) {
  ASSERT(n >= 0);
  if (n == 0) {
  	// Do nothing.
  } else if (n == 1) {
    __ popl(EAX);
  } else {
  	__ addl(ESP, Immediate(n * kWordSize));
  }
}

void Codegen::DoReturn() {
  __ popl(EAX);
  __ movl(ESP, EBP);
  __ popl(EBP);
  __ ret();
}

}  // namespace fletch