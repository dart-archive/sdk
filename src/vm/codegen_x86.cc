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

void Codegen::DoLoadStatic(int index) {
  __ movl(ECX, Address(EDI, Process::kStaticsOffset));
  int index_offset = index * kWordSize;
  __ pushl(Address(ECX, index_offset + Array::kSize - HeapObject::kTag));
}

void Codegen::DoLoadStaticInit(int index) {
  __ movl(ECX, Address(EDI, Process::kStaticsOffset));
  int index_offset = index * kWordSize;
  __ movl(EAX, Address(ECX, index_offset + Array::kSize - HeapObject::kTag));

  Label done;
  ASSERT(Smi::kTag == 0);
  __ testl(EAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &done);
  __ movl(EBX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movl(EBX, Address(EBX, Class::kInstanceFormatOffset - HeapObject::kTag));

  int type = InstanceFormat::INITIALIZER_TYPE;
  __ andl(EBX, Immediate(InstanceFormat::TypeField::mask()));
  __ cmpl(EBX, Immediate(type << InstanceFormat::TypeField::shift()));
  __ j(NOT_EQUAL, &done);

  printf("\tcall Function_%08x\n",
         Initializer::cast(program_->static_fields()->get(index))->function());

  __ Bind(&done);
  __ pushl(EAX);
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

void Codegen::DoStoreStatic(int index) {
  __ movl(EAX, Address(ESP, 0));
  __ movl(ECX, Address(EDI, Process::kStaticsOffset));
  int index_offset = index * kWordSize;
  __ movl(Address(ECX, index_offset + Array::kSize - HeapObject::kTag), EAX);
}

void Codegen::DoLoadInteger(int value) {
  __ pushl(Immediate(reinterpret_cast<int32>(Smi::FromWord(value))));
}

void Codegen::DoLoadProgramRoot(int offset) {
  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + offset);
  if (root->IsHeapObject()) {
    printf("\tpushl $O%08x + 1\n", HeapObject::cast(root)->address());
  } else {
    printf("\tpushl $0x%08x\n", root);
  }
}

void Codegen::DoLoadConstant(int bci, int offset) {
  Object* constant = Function::ConstantForBytecode(function_->bytecode_address_for(bci));
  if (constant->IsHeapObject()) {
    printf("\tpushl $O%08x + 1\n", HeapObject::cast(constant)->address());
  } else {
    printf("\tpushl $0x%08x\n", constant);
  }
}

void Codegen::DoBranch(BranchCondition condition, int from, int to) {
  Label skip;
  if (condition == BRANCH_ALWAYS) {
    // Do nothing.
  } else {
    __ popl(EBX);
    printf("\tcmpl $O%08x + 1, %%ebx\n", program_->true_object()->address());
    Condition cc = (condition == BRANCH_IF_TRUE) ? NOT_EQUAL : EQUAL;
    __ j(cc, &skip);
  }
  printf("\tjmp %u%s\n",
      reinterpret_cast<uint32>(function_->bytecode_address_for(to)),
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

void Codegen::DoInvokeTest(int offset) {
  __ movl(EAX, Address(ESP, 0 * kWordSize));
  __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(offset))));

  Label done;
  __ movl(ECX, Immediate(reinterpret_cast<int32>(Smi::FromWord(program()->smi_class()->id()))));
  __ testl(EAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &done);

  // TODO(kasperl): Use class id in objects? Less indirection.
  __ movl(ECX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movl(ECX, Address(ECX, Class::kIdOrTransformationTargetOffset - HeapObject::kTag));
  __ Bind(&done);

  __ addl(ECX, EDX);

  printf("\tmovl O%08x + %d(, %%ecx, 2), %%ecx\n",
      program()->dispatch_table()->address(),
      Array::kSize);

  Label nsm, end;
  __ cmpl(EDX, Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &nsm);
  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kTrueObjectOffset);
  printf("\tmovl $O%08x + 1, (%%esp)\n", HeapObject::cast(root)->address());
  __ jmp(&end);

  __ Bind(&nsm);
  root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kFalseObjectOffset);
  printf("\tmovl $O%08x + 1, (%%esp)\n", HeapObject::cast(root)->address());

  __ Bind(&end);
}

void Codegen::DoInvokeAdd() {
  Label done, slow;
  __ movl(EDX, Address(ESP, 0 * kWordSize));
  __ movl(EAX, Address(ESP, 1 * kWordSize));

  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ testl(EDX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, &slow);

  __ addl(EAX, EDX);
  __ j(NO_OVERFLOW, &done);

  __ Bind(&slow);
  printf("\tcall InvokeAdd\n");

  __ Bind(&done);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ popl(EAX);
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
  printf("\tmovl $O%08x + 1, %%eax\n", program_->true_object()->address());
  __ j(LESS, &done);

  printf("\tmovl $O%08x + 1, %%eax\n", program_->false_object()->address());
  __ jmp(&done);

  __ Bind(&slow);
  printf("\tcall InvokeLt\n");

  __ Bind(&done);
  __ movl(Address(ESP, 0 * kWordSize), EAX);
}

void Codegen::DoInvokeNative(Native native, int arity) {
  Label retry;
  __ Bind(&retry);

  // Compute the address for the first argument (we skip two empty slots).
  __ leal(EBX, Address(ESP, (arity + 2) * kWordSize));

  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);

  printf("\tcall %s\n", kNativeNames[native]);

  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);
  __ movl(ESP, EBX);

  Label failure;
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(EQUAL, &failure);

  __ movl(ESP, EBP);
  __ popl(EBP);

  __ ret();

  Label non_gc_failure;
  __ Bind(&failure);
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(NOT_EQUAL, &non_gc_failure);

  // Call the collector!
  DoSaveState(&retry);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleGC");
  DoRestoreState();

  __ Bind(&non_gc_failure);
  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ call("HandleObjectFromFailure");
  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);
  __ movl(ESP, EBX);
  __ pushl(EAX);
}

void Codegen::DoAllocate(Class* klass) {
  Label retry;
  __ Bind(&retry);

  int fields = klass->NumberOfInstanceFields();

  // TODO(ajohnsen): Handle immutable fields.

  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  printf("\tleal O%08x + 1, %%eax\n", klass->address());
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ movl(Address(ESP, 2 * kWordSize), Immediate(0));
  __ movl(Address(ESP, 3 * kWordSize), Immediate(0));
  __ call("HandleAllocate");

  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);
  __ movl(ESP, EBX);

  Label gc;
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  Label no_gc;
  __ j(NOT_EQUAL, &no_gc);

  DoSaveState(&retry);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleGC");
  DoRestoreState();

  __ Bind(&no_gc);

  int offset = Instance::kSize - HeapObject::kTag;
  for (int i = 0; i < fields; i++) {
    __ popl(EBX);
    __ movl(Address(EAX, (fields - (i + 1)) * kWordSize + offset), EBX);
  }

  __ pushl(EAX);
}

void Codegen::DoNegate() {
  Label store;

  __ movl(EBX, Address(ESP, 0 * kWordSize));

  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kTrueObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &store);
  root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kFalseObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ Bind(&store);
  __ movl(Address(ESP, 0 * kWordSize), EAX);
}

void Codegen::DoIdentical() {
  __ movl(EAX, Address(ESP, 0 * kWordSize));
  __ movl(EBX, Address(ESP, 1 * kWordSize));

  // TODO(ager): For now we bail out if we have two doubles or two
  // large integers and let the slow interpreter deal with it. These
  // cases could be dealt with directly here instead.
  Label fast_case;
  Label bail_out;

  // If either is a smi they are not both doubles or large integers.
  __ testl(EAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &fast_case);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &fast_case);

  // If they do not have the same type they are not both double or
  // large integers.
  __ movl(ECX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movl(ECX, Address(ECX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ movl(EDX, Address(EBX, HeapObject::kClassOffset - HeapObject::kTag));
  __ cmpl(ECX, Address(EDX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &fast_case);

  int double_type = InstanceFormat::DOUBLE_TYPE;
  int large_integer_type = InstanceFormat::LARGE_INTEGER_TYPE;
  int type_field_shift = InstanceFormat::TypeField::shift();

  __ andl(ECX, Immediate(InstanceFormat::TypeField::mask()));
  __ cmpl(ECX, Immediate(double_type << type_field_shift));
  __ j(EQUAL, &bail_out);
  __ cmpl(ECX, Immediate(large_integer_type << type_field_shift));
  __ j(EQUAL, &bail_out);

  __ Bind(&fast_case);

  Label true_case, done;
  __ cmpl(EBX, EAX);
  __ j(EQUAL, &true_case);

  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kFalseObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ jmp(&done);

  __ Bind(&true_case);
  root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kTrueObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ jmp(&done);


  __ Bind(&bail_out);
  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  __ movl(Address(ESP, 2 * kWordSize), EAX);
  __ call("HandleIdentical");

  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);
  __ movl(ESP, EBX);

  __ Bind(&done);
  DoDrop(1);
  __ movl(Address(ESP, 0 * kWordSize), EAX);
}

void Codegen::DoIdenticalNonNumeric() {
  __ movl(EAX, Address(ESP, 0 * kWordSize));
  __ movl(EBX, Address(ESP, 1 * kWordSize));

  __ addl(ESP, Immediate(2 * kWordSize));

  Label true_case, done;
  __ cmpl(EAX, EBX);
  __ j(EQUAL, &true_case);

  DoLoadProgramRoot(Program::kFalseObjectOffset);
  __ jmp(&done);

  __ Bind(&true_case);
  DoLoadProgramRoot(Program::kTrueObjectOffset);
  __ Bind(&done);
}

void Codegen::DoProcessYield() {
  __ movl(EAX, Immediate(1));
  // TODO(ajohnsen): Do better!
  __ jmp("Return");
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

void Codegen::DoSaveState(Label* label) {
  // Push resume address.
  __ movl(ECX, label);
  __ pushl(ECX);

  // Push frame pointer.
  __ pushl(EBP);

  // Update top in the stack. Ugh. Complicated.
  // First load the current coroutine's stack.
  __ movl(ECX, Address(EDI, Process::kCoroutineOffset));
  __ movl(ECX, Address(ECX, Coroutine::kStackOffset - HeapObject::kTag));
  // Calculate the index of the stack.
  __ subl(ESP, ECX);
  __ subl(ESP, Immediate(Stack::kSize - HeapObject::kTag));
  // We now have the distance to the top pointer in bytes. We need to
  // store the index, measured in words, as a Smi-tagged integer.  To do so,
  // shift by one.
  __ shrl(ESP, Immediate(1));
  // And finally store it in the stack object.
  __ movl(Address(ECX, Stack::kTopOffset - HeapObject::kTag), ESP);

  // Restore the C stack in ESP.
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
}

void Codegen::DoRestoreState() {
  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);

  // First load the current coroutine's stack.
  // Load the Dart stack pointer into ESP.
  __ movl(ESP, Address(EDI, Process::kCoroutineOffset));
  __ movl(ESP, Address(ESP, Coroutine::kStackOffset - HeapObject::kTag));
  // Load the top index.
  __ movl(ECX, Address(ESP, Stack::kTopOffset - HeapObject::kTag));
  // Load the address of the top position. Note top is a Smi-tagged count of
  // pointers, so we only need to multiply with 2 to get the offset in bytes.
  __ leal(ESP, Address(ESP, ECX, TIMES_2, Stack::kSize - HeapObject::kTag));

  // Read frame pointer.
  __ popl(EBP);

  __ ret();
}

}  // namespace fletch
