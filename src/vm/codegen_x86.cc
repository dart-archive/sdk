// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/codegen.h"

#include "src/vm/assembler.h"
#include "src/vm/process.h"

#include "src/shared/flags.h"
#include "src/shared/natives.h"

#define __ assembler()->

namespace fletch {

const char* kNativeNames[] = {
#define N(e, c, n) "Native_" #e,
  NATIVES_DO(N)
#undef N
};

void Codegen::DoEntry() {
  char name[256];
  sprintf(name, "%08x", function_);
  __ AlignToPowerOfTwo(4);
  __ Bind("Function_", name);

  // Calling convention
  // ------------------
  //  - EAX: function
  //  - EDI: process

  __ pushl(EBP);
  __ movl(EBP, ESP);
  __ pushl(Immediate(0));
}

void Codegen::DoLoadLocal(int index) {
  __ pushl(Address(ESP, index * kWordSize));
}

void Codegen::DoLoadField(int index) {
  __ popl(EAX);
  __ pushl(Address(EAX, index * kWordSize + Instance::kSize - HeapObject::kTag));
}

void Codegen::DoStoreLocal(int index) {
  __ movl(EAX, Address(ESP, 0));
  __ movl(Address(ESP, index * kWordSize), EAX);
}

void Codegen::DoStoreField(int index) {
  __ popl(EAX);  // Value.
  __ popl(ECX);
  __ movl(Address(ECX, index * kWordSize + Instance::kSize - HeapObject::kTag), EAX);
  __ pushl(EAX);
}

void Codegen::DoLoadInteger(int value) {
  __ pushl(Immediate(reinterpret_cast<int32>(Smi::FromWord(value))));
}

void Codegen::DoLoadProgramRoot(int offset) {
  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + offset);
  if (root->IsHeapObject()) {
    printf("\tpushl O%08x + 1\n", HeapObject::cast(root)->address());
  } else {
    printf("\tpushl 0x%08x\n", root);
  }
}

void Codegen::DoLoadConstant(int bci, int offset) {
  Object* constant = Function::ConstantForBytecode(function_->bytecode_address_for(bci));
  if (constant->IsHeapObject()) {
    printf("\tpushl O%08x + 1\n", HeapObject::cast(constant)->address());
  } else {
    printf("\tpushl 0x%08x\n", constant);
  }
}

void Codegen::DoBranch(BranchCondition condition, int from, int to) {
  Label skip;
  if (condition == BRANCH_ALWAYS) {
    // Do nothing.
  } else {
    __ popl(EBX);
    printf("\tcmpl %%ebx, O%08x + 1\n", program_->true_object()->address());
    Condition cc = (condition == BRANCH_IF_TRUE) ? NOT_EQUAL : EQUAL;
    __ j(cc, &skip);
  }
  printf("\tjmp %d%s\n",
      reinterpret_cast<int32>(function_->bytecode_address_for(to)),
      from >= to ? "b" : "f");
  if (condition != BRANCH_ALWAYS) {
    __ Bind(&skip);
  }
}

void Codegen::DoInvokeMethod(int arity, int offset) {
  __ movl(EAX, Address(ESP, arity * kWordSize));
  __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(offset))));
  printf("\tcall InvokeMethod\n");
  DoDrop(arity + 1);
  __ pushl(EAX);
}

void Codegen::DoInvokeStatic(int bci, int offset, Function* target) {
  printf("\tcall Function_%08x\n", target);
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

void Codegen::DoInvokeLt() {
  Label done, slow;
  __ movl(EAX, Address(ESP, 1 * kWordSize));
  __ popl(EDX);

  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ testl(EDX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ cmpl(EAX, EDX);
  printf("\tmovl O%08x + 1, %%eax\n", program_->true_object()->address());
  __ j(LESS, &done);

  printf("\tmovl O%08x + 1, %%eax\n", program_->false_object()->address());
  __ jmp(&done);

  __ Bind(&slow);
  printf("\tcall InvokeLt\n");

  __ Bind(&done);
  __ movl(Address(ESP, 0 * kWordSize), EAX);
}

void Codegen::DoInvokeNative(Native native, int arity) {
  // Compute the address for the first argument (we skip two empty slots).
  __ leal(EBX, Address(ESP, (arity + 2) * kWordSize));

  // TODO: switch to C stack.

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  printf("\tcall %s\n", kNativeNames[native]);
  __ int3();

  // TODO: switch to Dart stack.

  // TODO: check for failure.

  // Success!
  __ movl(ESP, EBP);
  __ popl(EBP);

  __ ret();
}

void Codegen::DoDrop(int n) {
  ASSERT(n >= 0);
  if (n == 0) {
  	// Do nothing.
  } else if (n == 1) {
    __ popl(EDX);
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