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
  sprintf(name, "%p", function_);
  __ Bind("Function_", name);

  // Calling convention
  // ------------------
  //  - EAX: function
  //  - EDI: process

  __ pushl(EBP);
  __ movl(EBP, ESP);
  __ pushl(EAX);  // Store the function on the stack.
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
  __ movl(EAX, Address(EDI, Process::kProgramOffset));
  __ pushl(Address(EAX, offset));
}

void Codegen::DoLoadConstant(int bci, int offset) {
  __ movl(EAX, Address(EBP, -1 * kWordSize));
  __ pushl(Address(EAX, Function::kSize - HeapObject::kTag + bci + offset));
}

void Codegen::DoBranch(BranchCondition condition, int target) {
  Label skip;
  if (condition == BRANCH_ALWAYS) {
    // Do nothing.
  } else {
    __ popl(EBX);
    __ movl(EAX, Address(EDI, Process::kProgramOffset));
    __ cmpl(EBX, Address(EAX, Program::kTrueObjectOffset));
    Condition cc = (condition == BRANCH_IF_TRUE) ? NOT_EQUAL : EQUAL;
    __ j(cc, &skip);
  }
  printf("\tjmp Function_%p_%d\n", function_, target);
  if (condition != BRANCH_ALWAYS) {
    __ Bind(&skip);
  }
}

void Codegen::DoInvokeMethod(int arity, int offset) {
  __ movl(EAX, Address(ESP, arity * kWordSize));
  __ movl(EDX, Immediate(offset));
  printf("\tcall InvokeMethod\n");

  /*
  Label done;
  __ movl(EAX, Address(ESP, arity * kWordSize));
  __ movl(EDX, Immediate(program()->smi_class()->id()));  // Smi tag?
  __ testl(EAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &done);

  // TODO(kasperl): Use class id in objects? Less indirection.
  __ movl(EDX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movl(EDX, Address(EDX, Class::kIdOrTransformationTargetOffset - HeapObject::kTag));
  __ Bind(&done);

  // TODO(kasperl): Avoid having to load the dispatch table all the time.
  __ movl(ESI, Address(EDI, Process::kProgramOffset));
  __ movl(ESI, Address(ESI, Program::kDispatchTableOffset));
  __ movl(ECX, Address(ESI, EDX, TIMES_2, Array::kSize - HeapObject::kTag + offset * kWordSize));

  __ cmpl(Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag), Immediate(offset));
  __ j(NOT_EQUAL, &done);  // TODO(kasperl): Deal with noSuchMethod.

  __ movl(EAX, Address(ECX, DispatchTableEntry::kFunctionOffset - HeapObject::kTag));
  __ call(Address(ECX, DispatchTableEntry::kTargetOffset - HeapObject::kTag));
  */

  DoDrop(arity);
  __ pushl(EAX);
}

void Codegen::DoInvokeStatic(int bci, int offset, Function* target) {
  __ movl(EAX, Address(EBP, -1 * kWordSize));
  __ movl(EAX, Address(EAX, Function::kSize - HeapObject::kTag + bci + offset));

  printf("\tcall Function_%p\n", target);
  DoDrop(target->arity());
  __ pushl(EAX);
}

void Codegen::DoInvokeAdd() {
  Label done, slow;
  __ movl(EAX, Address(ESP, 1 * kWordSize));
  __ popl(EDX);

  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ testl(EDX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ addl(EAX, EDX);
  __ j(NO_OVERFLOW, &done);

  __ Bind(&slow);
  printf("\tcall InvokeAdd\n");

  __ Bind(&done);
  __ movl(Address(ESP, 0 * kWordSize), EAX);
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