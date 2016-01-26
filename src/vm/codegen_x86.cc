// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/codegen.h"

#include "src/vm/assembler.h"
#include "src/vm/process.h"

#include "src/shared/flags.h"
#include "src/shared/natives.h"
#include "src/shared/selectors.h"

#define __ assembler()->

namespace fletch {

const char* kNativeNames[] = {
#define N(e, c, n) "Native_" #e,
  NATIVES_DO(N)
#undef N
};


void Codegen::GenerateHelpers() {
  __ BindWithPowerOfTwoAlignment("program_entry", 4);
  printf("\tjmp %ub\n", reinterpret_cast<uint32>(program()->entry()->bytecode_address_for(0)));

  printf("\n");
  __ BindWithPowerOfTwoAlignment("InvokeMethod", 4);
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

  Label nsm;
  __ cmpl(EDX, Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &nsm);
  __ jmp(Address(ECX, DispatchTableEntry::kCodeOffset - HeapObject::kTag));

  __ Bind(&nsm);
  // TODO(ajohnsen): Do NSM!
  __ call("Throw");

  if (add_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeAdd", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(add_offset_))));
    __ jmp("InvokeMethod");
  }

  if (sub_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeSub", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(sub_offset_))));
    __ jmp("InvokeMethod");
  }

  if (eq_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeEq", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(eq_offset_))));
    __ jmp("InvokeMethod");
  }

  if (ge_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeGe", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(ge_offset_))));
    __ jmp("InvokeMethod");
  }

  if (gt_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeGt", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(gt_offset_))));
    __ jmp("InvokeMethod");
  }

  if (le_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeLe", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(le_offset_))));
    __ jmp("InvokeMethod");
  }

  if (lt_offset_ >= 0) {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeLt", 4);
    __ movl(EAX, Address(ESP, 2 * kWordSize));
    __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(lt_offset_))));
    __ jmp("InvokeMethod");
  }

  printf("\n");
  __ BindWithPowerOfTwoAlignment("CollectGarbage", 4);
  DoSaveState();
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleGC");
  DoRestoreState();
  __ ret();

  printf("\n");
  __ BindWithPowerOfTwoAlignment("StackOverflow", 4);
  __ int3();

  printf("\n");
  __ BindWithPowerOfTwoAlignment("Throw", 4);
  __ int3();

  printf("\n");
  __ BindWithPowerOfTwoAlignment("NativeFailure", 4);
  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ call("HandleObjectFromFailure");
  __ movl(Address(EDI, Process::kNativeStackOffset), ESP);
  __ movl(ESP, EBX);
  __ ret();

  {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("Identical", 4);
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

    Label true_case;
    __ cmpl(EBX, EAX);
    __ ret();

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

    Object* root = *reinterpret_cast<Object**>(
        reinterpret_cast<uint8*>(program_) + Program::kTrueObjectOffset);
    printf("\tcmpl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());

    __ ret();
  }

  {
    printf("\n");
    __ BindWithPowerOfTwoAlignment("InvokeTest", 4);

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

    __ cmpl(EDX, Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag));
    __ ret();
  }
}

void Codegen::DoEntry() {
  char name[256];
  sprintf(name, "%08x", function_);
  __ AlignToPowerOfTwo(4);
  __ Bind("Function_", name);
}

void Codegen::DoSetupFrame() {
  // Calling convention
  // ------------------
  //  - EAX: function
  //  - EDI: process

  __ pushl(EBP);
  __ movl(EBP, ESP);
  __ pushl(Immediate(0));
  DoStackOverflowCheck(0);
}

void Codegen::DoLoadLocal(int index) {
  basic_block_.MaterializeKeepRegister();
  if (basic_block_.IsTopRegister()) {
    if (index == 0) {
      __ pushl(EAX);
    } else {
      basic_block_.Materialize();
    }
  }
  if (!basic_block_.IsTopRegister()) {
    __ movl(EAX, Address(ESP, index * kWordSize));
  } else {
    basic_block_.SetTop(Slot::Unknown());
  }
  basic_block_.Push(Slot::Register());
}

void Codegen::DoLoadField(int index) {
  basic_block_.MaterializeKeepRegister();
  if (!basic_block_.IsTopRegister()) {
    __ popl(EAX);
  }
  basic_block_.Pop();
  __ movl(EAX,
          Address(EAX, index * kWordSize + Instance::kSize - HeapObject::kTag));
  basic_block_.Push(Slot::Register());
}

void Codegen::DoLoadStatic(int index) {
  basic_block_.Materialize();
  __ movl(ECX, Address(EDI, Process::kStaticsOffset));
  int index_offset = index * kWordSize;
  __ movl(EAX, Address(ECX, index_offset + Array::kSize - HeapObject::kTag));
  basic_block_.Push(Slot::Register());
}

void Codegen::DoLoadStaticInit(int index) {
  basic_block_.Materialize();
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
  basic_block_.Push(Slot::Register());
}

void Codegen::DoStoreLocal(int index) {
  basic_block_.SetAtOffset(index, Slot::Unknown());
  basic_block_.MaterializeKeepRegister();
  if (basic_block_.IsTopRegister()) {
    index--;
  } else {
    __ movl(EAX, Address(ESP, 0));
  }
  __ movl(Address(ESP, index * kWordSize), EAX);
}

void Codegen::DoStoreField(int index) {
  basic_block_.MaterializeKeepRegister();
  if (basic_block_.IsTopRegister()) {
    index--;
  } else {
    __ popl(EAX);  // Value.
  }
  __ popl(ECX);
  __ movl(Address(ECX, index * kWordSize + Instance::kSize - HeapObject::kTag), EAX);
}

void Codegen::DoStoreStatic(int index) {
  basic_block_.MaterializeKeepRegister();
  if (!basic_block_.IsTopRegister()) {
    __ movl(EAX, Address(ESP, 0));
  }
  __ movl(ECX, Address(EDI, Process::kStaticsOffset));
  int index_offset = index * kWordSize;
  __ movl(Address(ECX, index_offset + Array::kSize - HeapObject::kTag), EAX);
}

void Codegen::DoLoadInteger(int value) {
  basic_block_.Materialize();
  basic_block_.Push(Slot(Smi::FromWord(value)));
}

void Codegen::DoLoadProgramRoot(int offset) {
  basic_block_.Materialize();
  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + offset);
  if (root->IsHeapObject()) {
    printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  } else {
    printf("\tmovl $0x%08x, %%eax\n", root);
  }
  basic_block_.Push(Slot::Register());
}

void Codegen::DoLoadConstant(int bci, int offset) {
  basic_block_.Materialize();
  Object* constant = Function::ConstantForBytecode(function_->bytecode_address_for(bci));
  if (constant->IsHeapObject()) {
    printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(constant)->address());
    basic_block_.Push(Slot::Register());
  } else {
    ASSERT(constant->IsSmi());
    basic_block_.Push(Slot(Smi::cast(constant)));
  }
}

void Codegen::DoBranch(BranchCondition condition, int from, int to) {
  Label skip;
  if (condition == BRANCH_ALWAYS) {
    basic_block_.Materialize();
    // Do nothing.
    printf("\tjmp %u%s\n",
           reinterpret_cast<uint32>(function_->bytecode_address_for(to)),
           from >= to ? "b" : "f");
  } else {
    if (!basic_block_.IsTopCondition()) {
      if (!basic_block_.IsTopRegister()) {
        basic_block_.Materialize();
        __ popl(EAX);
      }
      basic_block_.SetTop(Slot(EQUAL));
      printf("\tcmpl $O%08x + 1, %%eax\n", program_->true_object()->address());
    }
    Condition cc = basic_block_.Pop().condition();
    if (condition == BRANCH_IF_FALSE) cc = Assembler::InvertCondition(cc);
    printf("\tj%s %u%s\n",
      Assembler::ConditionMnemonic(cc),
      reinterpret_cast<uint32>(function_->bytecode_address_for(to)),
      from >= to ? "b" : "f");
  }
}

void Codegen::DoInvokeMethod(Class* klass, int arity, int offset) {
  printf("// Invoke: %i, %i (%p)\n", offset, arity, klass);
  bool receiver_in_eax = basic_block_.IsTopRegister() && arity == 0;
  Slot receiver = basic_block_.GetAtOffset(arity);
  if (receiver.IsThis() && klass != NULL) {
    Function* target = NULL;
    for (int i = klass->id(); i < klass->child_id(); i++) {
      DispatchTableEntry* entry = DispatchTableEntry::cast(
          program()->dispatch_table()->get(i + offset));
      if (i == klass->id()) target = entry->target();
      if (entry->offset()->value() != offset || target != entry->target()) {
        target = NULL;
        break;
      }
    }

    printf("// Target: %p\n", target);
    if (target != NULL) {
      Intrinsic intrinsic = target->ComputeIntrinsic(IntrinsicsTable::GetDefault());
      switch (intrinsic) {
        case kIntrinsicGetField: {
          ASSERT(arity == 0);
          basic_block_.MaterializeKeepRegister();
          if (!basic_block_.IsTopRegister()) __ popl(EAX);
          int field = *target->bytecode_address_for(2);
          printf("// Inlined getter, field %i\n", field);
          int offset = field * kWordSize + Instance::kSize - HeapObject::kTag;
          __ movl(EAX, Address(EAX, offset));
          basic_block_.SetTop(Slot::Register());
          break;
        }

        case kIntrinsicSetField: {
          ASSERT(arity == 1);
          basic_block_.MaterializeKeepRegister();
          if (!basic_block_.IsTopRegister()) __ popl(EAX);
          __ popl(ECX);
          int field = *target->bytecode_address_for(3);
          printf("// Inlined setter, field %i\n", field);
          int offset = field * kWordSize + Instance::kSize - HeapObject::kTag;
          __ movl(Address(ECX, offset), EAX);
          basic_block_.Drop(2);
          basic_block_.Push(Slot::Register());
          break;
        }

        default: {
          DoInvokeStatic(0, 0, target);
          break;
        }
      }
      return;
    }
  }
  basic_block_.Materialize();

  if (!receiver_in_eax) {
    __ movl(EAX, Address(ESP, arity * kWordSize));
  }

  Label end;

  // See if we can find a unique function for the call.
  Function* target = NULL;
  Array* table = program()->dispatch_table();

  for (int i = 0; i < table->length(); i++) {
    DispatchTableEntry* entry = DispatchTableEntry::cast(table->get(i));
    if (entry->offset()->value() == offset) {
      if (target == NULL) {
        target = entry->target();
      } else if (target != entry->target()) {
        target = NULL;
        break;
      }
    }
  }

  Label nsm;
  Class* target_class = (*function_owners_)[target];
  if (target_class != NULL) {
    // There is only one function we can end up calling, and it has a distinct
    // owner. We can simple test the class range, and fall back to NSM.
    printf("// Unique target: %p(%p)\n", target, target_class);

    int lower_id = target_class->id();
    int upper_id = target_class->child_id();

    Label done;
    int smi_class_id = program()->smi_class()->id();
    if (smi_class_id < lower_id || smi_class_id >= upper_id) {
      __ testl(EAX, Immediate(Smi::kTagMask));
      __ j(ZERO, &nsm);
    } else {
      __ movl(ECX, Immediate(reinterpret_cast<int32>(Smi::FromWord(program()->smi_class()->id()))));
      __ testl(EAX, Immediate(Smi::kTagMask));
      __ j(ZERO, &done);
    }

    // TODO(kasperl): Use class id in objects? Less indirection.
    __ movl(ECX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
    __ movl(ECX, Address(ECX, Class::kIdOrTransformationTargetOffset - HeapObject::kTag));

    // Class ID is now in EDX.
    __ Bind(&done);

    if (lower_id + 1 == upper_id) {
      printf("// - precise test\n");
      __ cmpl(ECX,
              Immediate(reinterpret_cast<int32>(Smi::FromWord(lower_id))));
      __ j(NOT_EQUAL, &nsm);
    } else {
      printf("// - range test\n");
      __ cmpl(ECX,
              Immediate(reinterpret_cast<int32>(Smi::FromWord(lower_id))));
      __ j(LESS, &nsm);
      __ cmpl(ECX,
              Immediate(reinterpret_cast<int32>(Smi::FromWord(upper_id))));
      __ j(GREATER_EQUAL, &nsm);
    }


    printf("\tcall Function_%08x\n", target);

    __ jmp(&end);

    __ Bind(&nsm);
    // TODO(ajohnsen): Do NSM!
    __ call("Throw");
    __ Bind(&end);
  } else {
    Label done;
    __ movl(ECX, Immediate(reinterpret_cast<int32>(Smi::FromWord(program()->smi_class()->id()))));
    __ testl(EAX, Immediate(Smi::kTagMask));
    __ j(ZERO, &done);

    // TODO(kasperl): Use class id in objects? Less indirection.
    __ movl(ECX, Address(EAX, HeapObject::kClassOffset - HeapObject::kTag));
    __ movl(ECX, Address(ECX, Class::kIdOrTransformationTargetOffset - HeapObject::kTag));

  // Class ID is now in EDX.
  __ Bind(&done);
    printf("\tmovl O%08x + %d(, %%ecx, 2), %%ecx\n",
           table->address(),
           Array::kSize + offset * kWordSize);

    __ cmpl(Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag),
            Immediate(reinterpret_cast<int32>(Smi::FromWord(offset))));
    __ j(EQUAL, &end);
    __ Bind(&nsm);
    // TODO(ajohnsen): Do NSM!
    __ call("Throw");
    __ Bind(&end);
    __ call(Address(ECX, DispatchTableEntry::kCodeOffset - HeapObject::kTag));
  }

  DoDropMaterialized(arity + 1);
  basic_block_.Drop(arity + 1);
  basic_block_.Push(Slot::Register());
}

void Codegen::DoInvokeStatic(int bci, int offset, Function* target) {
  basic_block_.Materialize();
  printf("\tcall Function_%08x\n", target);
  int arity = target->arity();
  DoDropMaterialized(arity);
  basic_block_.Drop(arity);
  basic_block_.Push(Slot::Register());
}

void Codegen::DoInvokeTest(int offset) {
  basic_block_.MaterializeKeepRegister();
  if (!basic_block_.IsTopRegister()) {
    __ popl(EAX);
  }

  __ movl(EDX, Immediate(reinterpret_cast<int32>(Smi::FromWord(offset))));

  __ call("InvokeTest");

  basic_block_.SetTop(Slot(EQUAL));
}

void Codegen::DoInvokeAdd() {
  Label done, slow;
  if (basic_block_.IsTopSmi()) {
    __ movl(EAX, Address(ESP, 0 * kWordSize));

    __ testl(EAX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ addl(EAX, Immediate(reinterpret_cast<int32>(basic_block_.Top().smi())));

    __ j(NO_OVERFLOW, &done);
  } else {
    basic_block_.MaterializeKeepRegister();
    if (basic_block_.IsTopRegister()) {
      __ movl(EDX, Address(ESP, 0 * kWordSize));
    } else {
      __ movl(EAX, Address(ESP, 0 * kWordSize));
      __ movl(EDX, Address(ESP, 1 * kWordSize));
    }

    __ testl(EAX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ testl(EDX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ addl(EDX, EAX);
    __ j(OVERFLOW_, &slow);
    __ movl(EAX, EDX);
    __ jmp(&done);
  }

  __ Bind(&slow);

  bool materialized = basic_block_.IsTopMaterialized();
  if (!materialized) basic_block_.Materialize();
  printf("\tcall InvokeAdd\n");
  if (!materialized) __ popl(EDX);

  __ Bind(&done);
  if (!materialized) {
    __ popl(EDX);
  } else {
    DoDropMaterialized(2);
  }

  basic_block_.Drop(2);
  basic_block_.Push(Slot::Register());
}

void Codegen::DoInvokeSub() {
  Label done, slow;
  if (basic_block_.IsTopSmi()) {
    __ movl(EAX, Address(ESP, 0 * kWordSize));

    __ testl(EAX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ subl(EAX, Immediate(reinterpret_cast<int32>(basic_block_.Top().smi())));

    __ j(NO_OVERFLOW, &done);
  } else {
    basic_block_.MaterializeKeepRegister();
    if (basic_block_.IsTopRegister()) {
      __ movl(EDX, Address(ESP, 0 * kWordSize));
    } else {
      __ movl(EAX, Address(ESP, 0 * kWordSize));
      __ movl(EDX, Address(ESP, 1 * kWordSize));
    }

    __ testl(EAX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ testl(EDX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ subl(EDX, EAX);
    __ j(OVERFLOW_, &slow);
    __ movl(EAX, EDX);
    __ jmp(&done);
  }

  __ Bind(&slow);

  bool materialized = basic_block_.IsTopMaterialized();
  if (!materialized) basic_block_.Materialize();
  printf("\tcall InvokeSub\n");
  if (!materialized) __ popl(EDX);

  __ Bind(&done);
  if (!materialized) {
    __ popl(EDX);
  } else {
    DoDropMaterialized(2);
  }

  basic_block_.Drop(2);
  basic_block_.Push(Slot::Register());
}

void Codegen::DoInvokeCompare(Condition condition, const char* bailout) {
  Label done, slow;
  bool materialized = !basic_block_.IsTopSmi();
  if (basic_block_.IsTopSmi()) {
    __ movl(EDX, Address(ESP, 0 * kWordSize));

    __ testl(EDX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ cmpl(EDX, Immediate(reinterpret_cast<int32>(basic_block_.Top().smi())));

    __ jmp(&done);

    __ Bind(&slow);

    basic_block_.Materialize();
    printf("\tcall %s\n", bailout);
    __ popl(EDX);
  } else {
    basic_block_.Materialize();
    __ movl(EBX, Address(ESP, 1 * kWordSize));
    __ movl(EDX, Address(ESP, 0 * kWordSize));

    __ testl(EBX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ testl(EDX, Immediate(Smi::kTagSize));
    __ j(NOT_ZERO, &slow);

    __ cmpl(EBX, EDX);

    __ jmp(&done);

    __ Bind(&slow);
    printf("\tcall %s\n", bailout);
  }

  ASSERT(program_->true_object()->address() > program_->false_object()->address());
  if (condition == EQUAL) {
    printf("\tcmpl $O%08x + 1, %%eax\n", program_->true_object()->address());
  } else if (condition == LESS) {
    printf("\tmovl $O%08x + 1 - 4, %%ecx\n", program_->true_object()->address());
    printf("\tcmpl %%eax, %%ecx\n");
  } else if (condition == LESS_EQUAL) {
    printf("\tmovl $O%08x + 1, %%ecx\n", program_->true_object()->address());
    printf("\tcmpl %%eax, %%ecx\n");
  } else if (condition == GREATER) {
    printf("\tcmpl $O%08x + 1 + 4, %%eax\n", program_->false_object()->address());
  } else if (condition == GREATER_EQUAL) {
    printf("\tcmpl $O%08x + 1, %%eax\n", program_->false_object()->address());
  } else {
    UNREACHABLE();
  }
  __ Bind(&done);

  if (!materialized) {
    __ popl(EAX);
  } else {
    __ popl(EAX);
    __ popl(EAX);
  }
  basic_block_.Drop(2);
  basic_block_.Push(Slot(condition));
}

void Codegen::DoInvokeNative(Native native, int arity) {
  basic_block_.Materialize();
  Label retry;
  __ Bind(&retry);

  // Compute the address for the first argument (we skip two empty slots).
  __ leal(ECX, Address(ESP, (arity + 2) * kWordSize));

  __ movl(EBX, ESP);
  __ movl(ESP, Address(EDI, Process::kNativeStackOffset));
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), ECX);

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
  __ call("CollectGarbage");
  __ jmp(&retry);

  __ Bind(&non_gc_failure);
  __ call("NativeFailure");
  __ pushl(EAX);
}

void Codegen::DoAllocate(Class* klass) {
  basic_block_.Materialize();
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

  __ call("CollectGarbage");
  __ jmp(&retry);

  __ Bind(&no_gc);

  int offset = Instance::kSize - HeapObject::kTag;
  for (int i = 0; i < fields; i++) {
    __ popl(EBX);
    __ movl(Address(EAX, (fields - (i + 1)) * kWordSize + offset), EBX);
  }

  basic_block_.Drop(fields);
  basic_block_.Push(Slot::Register());
}

void Codegen::DoNegate() {
  if (basic_block_.IsTopCondition()) {
    Condition condition = basic_block_.Pop().condition();
    basic_block_.Push(Slot(Assembler::InvertCondition(condition)));
    return;
  }

  basic_block_.MaterializeKeepRegister();
  Label store;

  if (basic_block_.IsTopRegister()) {
    __ movl(EBX, EAX);
  } else {
    __ movl(EBX, Address(ESP, 0 * kWordSize));
  }

  Object* root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kTrueObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &store);
  root = *reinterpret_cast<Object**>(
      reinterpret_cast<uint8*>(program_) + Program::kFalseObjectOffset);
  printf("\tmovl $O%08x + 1, %%eax\n", HeapObject::cast(root)->address());
  __ Bind(&store);

  if (!basic_block_.IsTopRegister()) {
    __ movl(Address(ESP, 0 * kWordSize), EAX);
  }
}

void Codegen::DoIdentical() {
  basic_block_.MaterializeKeepRegister();
  if (basic_block_.IsTopRegister()) {
    __ popl(EBX);
  } else {
    __ movl(EAX, Address(ESP, 0 * kWordSize));
    __ movl(EBX, Address(ESP, 1 * kWordSize));
    DoDrop(2);
  }

  __ call("Identical");

  basic_block_.Drop(2);
  basic_block_.Push(Slot(EQUAL));
}

void Codegen::DoIdenticalNonNumeric() {
  basic_block_.MaterializeKeepRegister();
  if (basic_block_.IsTopRegister()) {
    __ popl(EBX);
  } else {
    __ movl(EAX, Address(ESP, 0 * kWordSize));
    __ movl(EBX, Address(ESP, 1 * kWordSize));
    DoDrop(2);
  }

  __ cmpl(EAX, EBX);

  basic_block_.Drop(2);
  basic_block_.Push(Slot(EQUAL));
}

void Codegen::DoProcessYield() {
  basic_block_.Materialize();
  __ movl(EAX, Immediate(1));
  // TODO(ajohnsen): Do better!
  __ jmp("Return");
}

void Codegen::DoDrop(int n) {
  ASSERT(n >= 0);
  while (n > 0) {
    switch (basic_block_.Top().kind()) {
      case Slot::kRegisterSlot:
      case Slot::kConditionSlot:
        basic_block_.Drop(1);
        n--;
        continue;

      default:
        basic_block_.Materialize();
        break;
    }
    break;
  }
  if (n == 0) {
    // Do nothing.
  } else if (n == 1) {
    __ popl(EDX);
  } else {
    __ addl(ESP, Immediate(n * kWordSize));
  }
  basic_block_.Drop(n);
}

void Codegen::DoDropMaterialized(int n) {
  ASSERT(n >= 0);
  ASSERT(basic_block_.Top().IsMaterialized());
  if (n == 0) {
    // Do nothing.
  } else if (n == 1) {
    __ popl(EDX);
  } else {
    __ addl(ESP, Immediate(n * kWordSize));
  }
}

void Codegen::DoReturn() {
  if (basic_block_.IsTopCondition()) {
    basic_block_.ConditionToRegister();
  }
  basic_block_.MaterializeKeepRegister();
  if (!basic_block_.IsTopRegister()) {
    __ popl(EAX);
  }
  __ movl(ESP, EBP);
  __ popl(EBP);
  __ ret();
}

void Codegen::DoThrow() {
  __ call("Throw");
}

void Codegen::DoSaveState() {
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
}

void Codegen::DoStackOverflowCheck(int size) {
  basic_block_.Materialize();
  __ movl(EBX, Address(EDI, Process::kStackLimitOffset));
  __ cmpl(ESP, EBX);
  if (size == 0) {
    __ j(BELOW_EQUAL, "StackOverflow");
  } else {
    Label done;
    __ j(BELOW, &done);
    __ movl(EAX, Immediate(size));
    __ jmp("StackOverflow");
    __ Bind(&done);
  }
}

void Codegen::DoIntrinsicGetField(int field) {
  __ movl(EAX, Address(ESP, 1 * kWordSize));
  int offset = field * kWordSize + Instance::kSize - HeapObject::kTag;
  __ movl(EAX, Address(EAX, offset));
  __ ret();
  printf("\n");
}

void Codegen::DoIntrinsicSetField(int field) {
  __ movl(EAX, Address(ESP, 1 * kWordSize));
  __ movl(ECX, Address(ESP, 2 * kWordSize));
  int offset = field * kWordSize + Instance::kSize - HeapObject::kTag;
  __ movl(Address(ECX, offset), EAX);
  __ ret();
  printf("\n");
}

void Codegen::DoIntrinsicListLength() {
  // Load the backing store (array) from the first instance field of the list.
  __ movl(ECX, Address(ESP, 1 * kWordSize));  // List
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EAX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  __ ret();
}

void Codegen::DoIntrinsicListIndexGet() {
  __ movl(EBX, Address(ESP, 1 * kWordSize));  // Index
  __ movl(ECX, Address(ESP, 2 * kWordSize));  // List

  Label failure;
  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &failure);
  __ cmpl(EBX, Immediate(0));
  __ j(LESS, &failure);

  // Load the backing store (array) from the first instance field of the list.
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EDX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpl(EBX, EDX);
  __ j(GREATER_EQUAL, &failure);

  // Load from the array and continue.
  ASSERT(Smi::kTagSize == 1);
  __ movl(EAX, Address(ECX, EBX, TIMES_2, Array::kSize - HeapObject::kTag));
  __ ret();

  __ Bind(&failure);
}

void Codegen::DoIntrinsicListIndexSet() {
  __ movl(EBX, Address(ESP, 2 * kWordSize));  // Index
  __ movl(ECX, Address(ESP, 3 * kWordSize));  // List

  Label failure;
  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &failure);
  __ cmpl(EBX, Immediate(0));
  __ j(LESS, &failure);

  // Load the backing store (array) from the first instance field of the list.
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EDX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpl(EBX, EDX);
  __ j(GREATER_EQUAL, &failure);

  // Store to the array and continue.
  ASSERT(Smi::kTagSize == 1);
  __ movl(EAX, Address(ESP, 1 * kWordSize));
  // Index (in EBX) is already smi-taged, so only scale by TIMES_2.
  __ movl(Address(ECX, EBX, TIMES_2, Array::kSize - HeapObject::kTag), EAX);
  __ ret();

  __ Bind(&failure);
}

Program* BasicBlock::program() const {
  return codegen_->program();
}

Assembler* BasicBlock::assembler() const {
  return codegen_->assembler();
}

void BasicBlock::SmiToRegister() {
  Slot slot = Pop();
  __ movl(EAX, Immediate(reinterpret_cast<int32>(slot.smi())));
  Push(Slot::Register());
}

void BasicBlock::ConditionToRegister() {
  Slot slot = Pop();
  printf("\tmovl $O%08x + 1, %%eax\n", program()->false_object()->address());
  printf("\tmovl $O%08x + 1, %%ecx\n", program()->true_object()->address());
  __ cmov(slot.condition(), EAX, ECX);
  Push(Slot::Register());
}

void BasicBlock::Materialize() {
  switch (Top().kind()) {
    case Slot::kConditionSlot: {
      ConditionToRegister();
      __ pushl(EAX);
      SetTop(Slot::Unknown());
      break;
    }

    case Slot::kRegisterSlot: {
      __ pushl(EAX);
      SetTop(Slot::Unknown());
      break;
    }

    case Slot::kThisRegisterSlot: {
      __ pushl(EAX);
      SetTop(Slot::This());
      break;
    }

    case Slot::kSmiSlot: {
      __ pushl(Immediate(reinterpret_cast<int32>(Pop().smi())));
      SetTop(Slot::Unknown());
      break;
    }

    case Slot::kUnknownSlot:
    case Slot::kThisSlot:
      break;

    default:
      ASSERT(false);
  }
}

}  // namespace fletch
