// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_ARM)

#include "src/shared/bytecodes.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/assembler.h"
#include "src/vm/generator.h"
#include "src/vm/interpreter.h"
#include "src/vm/intrinsics.h"
#include "src/vm/object.h"
#include "src/vm/process.h"
#include "src/vm/program.h"

#define __ assembler()->

namespace fletch {

class InterpreterGenerator {
 public:
  explicit InterpreterGenerator(Assembler* assembler)
      : assembler_(assembler) { }

  void Generate();

  virtual void GeneratePrologue() = 0;
  virtual void GenerateEpilogue() = 0;

#define V(name, format, size, stack_diff, print)        \
  virtual void Do##name() = 0;
  BYTECODES_DO(V)
#undef V

#define V(name) \
  virtual void DoIntrinsic##name() = 0;
INTRINSICS_DO(V)
#undef V

 protected:
  Assembler* assembler() const { return assembler_; }

 private:
  Assembler* const assembler_;
};

void InterpreterGenerator::Generate() {
  GeneratePrologue();
  GenerateEpilogue();

#define V(name, format, size, stack_diff, print) \
  assembler()->Bind("BC_" #name);                \
  Do##name();
  BYTECODES_DO(V)
#undef V

#define V(name)                          \
  assembler()->Bind("Intrinsic_" #name); \
  DoIntrinsic##name();
INTRINSICS_DO(V)
#undef V

  assembler()->Align(4);
  printf("\nInterpretFast_DispatchTable:\n");
#define V(name, format, size, stack_diff, print)        \
  assembler()->DefineLong("BC_" #name);
  BYTECODES_DO(V)
#undef V
}

class InterpreterGeneratorARM: public InterpreterGenerator {
 public:
  explicit InterpreterGeneratorARM(Assembler* assembler)
      : InterpreterGenerator(assembler) { }

  // Registers
  // ---------
  //   r6: stack pointer (top)
  //   r5: bytecode pointer
  //   r4: current process

  virtual void GeneratePrologue();
  virtual void GenerateEpilogue();

  virtual void DoLoadLocal0();
  virtual void DoLoadLocal1();
  virtual void DoLoadLocal2();
  virtual void DoLoadLocal();

  virtual void DoLoadBoxed();
  virtual void DoLoadStatic();
  virtual void DoLoadStaticInit();
  virtual void DoLoadField();

  virtual void DoLoadConst();
  virtual void DoLoadConstUnfold();

  virtual void DoStoreLocal();
  virtual void DoStoreBoxed();
  virtual void DoStoreStatic();
  virtual void DoStoreField();

  virtual void DoLoadLiteralNull();
  virtual void DoLoadLiteralTrue();
  virtual void DoLoadLiteralFalse();
  virtual void DoLoadLiteral0();
  virtual void DoLoadLiteral1();
  virtual void DoLoadLiteral();
  virtual void DoLoadLiteralWide();

  virtual void DoInvokeMethod();
  virtual void DoInvokeStatic();
  virtual void DoInvokeStaticUnfold();
  virtual void DoInvokeFactory();
  virtual void DoInvokeFactoryUnfold();

  virtual void DoInvokeNative();
  virtual void DoInvokeNativeYield();
  virtual void DoInvokeTest();

  virtual void DoInvokeEq();
  virtual void DoInvokeLt();
  virtual void DoInvokeLe();
  virtual void DoInvokeGt();
  virtual void DoInvokeGe();

  virtual void DoInvokeAdd();
  virtual void DoInvokeSub();
  virtual void DoInvokeMod();
  virtual void DoInvokeMul();
  virtual void DoInvokeTruncDiv();

  virtual void DoInvokeBitNot();
  virtual void DoInvokeBitAnd();
  virtual void DoInvokeBitOr();
  virtual void DoInvokeBitXor();
  virtual void DoInvokeBitShr();
  virtual void DoInvokeBitShl();

  virtual void DoPop();
  virtual void DoReturn();

  virtual void DoBranchLong();
  virtual void DoBranchIfTrueLong();
  virtual void DoBranchIfFalseLong();

  virtual void DoBranchBack();
  virtual void DoBranchBackIfTrue();
  virtual void DoBranchBackIfFalse();

  virtual void DoBranchBackLong();
  virtual void DoBranchBackIfTrueLong();
  virtual void DoBranchBackIfFalseLong();

  virtual void DoAllocate();
  virtual void DoAllocateUnfold();
  virtual void DoAllocateBoxed();

  virtual void DoNegate();

  virtual void DoStackOverflowCheck();

  virtual void DoThrow();
  virtual void DoSubroutineCall();
  virtual void DoSubroutineReturn();

  virtual void DoProcessYield();
  virtual void DoCoroutineChange();

  virtual void DoIdentical();
  virtual void DoIdenticalNonNumeric();

  virtual void DoEnterNoSuchMethod();
  virtual void DoExitNoSuchMethod();

  virtual void DoFrameSize();
  virtual void DoMethodEnd();

  virtual void DoIntrinsicObjectEquals();
  virtual void DoIntrinsicGetField();
  virtual void DoIntrinsicSetField();
  virtual void DoIntrinsicListIndexGet();
  virtual void DoIntrinsicListIndexSet();
  virtual void DoIntrinsicListLength();

 private:
  Label done_;
  Label check_stack_overflow_;
  Label gc_;

  void Bailout();

  void LoadTrue(Register reg);
  void LoadFalse(Register reg);
  void LoadNull(Register reg);

  void LoadLocal(Register reg, int index);
  void StoreLocal(Register reg, int index);

  void Push(Register reg);
  void Pop(Register reg);
  void Drop(int n);

  void InvokeCompare(Condition condition);
  void InvokeMethod(bool test);
  void InvokeNative(bool yield);
  void InvokeStatic(bool unfolded);

  void CheckStackOverflow(int size);

  void Dispatch(int size);

  void SaveState();
  void RestoreState();

  static int ComputeStackPadding(int reserved, int extra) {
    const int kAlignment = 8;
    int rounded = (reserved + extra + kAlignment - 1) & ~(kAlignment - 1);
    return rounded - reserved;
  }

  static RegisterList RegisterRange(Register first, Register last) {
    ASSERT(first <= last);
    RegisterList value = 0;
    for (int i = first; i <= last; i++) {
      value |= (1 << i);
    }
    return value;
  }
};

GENERATE(, InterpretFast) {
  InterpreterGeneratorARM generator(assembler);
  generator.Generate();
}

void InterpreterGeneratorARM::GeneratePrologue() {
  // Push callee-saved registers.
  __ push(RegisterRange(R4, R11) | RegisterRange(LR, LR));

  // Setup process pointer in R4.
  __ mov(R4, R0);

  // Pad the stack to gaurantee the right alignment for calls.
  int padding = ComputeStackPadding(8 * kWordSize, 0);
  if (padding > 0) __ sub(SP, SP, Immediate(padding));

  // Restore the register state and dispatch to the first bytecode.
  RestoreState();
  Dispatch(0);
}

void InterpreterGeneratorARM::GenerateEpilogue() {
  // Done. Save the register state.
  __ Bind(&done_);
  SaveState();

  // Undo stack padding.
  Label undo_padding;
  __ Bind(&undo_padding);
  int padding = ComputeStackPadding(8 * kWordSize, 0);
  if (padding > 0) __ add(SP, SP, Immediate(padding));

  // Restore callee-saved registers and return.
  __ pop(RegisterRange(R4, R11) | RegisterRange(LR, LR));
  __ bx(LR);

  // Handle GC and re-interpret current bytecode.
  __ Bind(&gc_);
  SaveState();
  __ mov(R0, R4);
  __ bl("HandleGC");
  RestoreState();
  Dispatch(0);

  // Stack overflow handling (slow case).
  Label stay_fast;
  __ Bind(&check_stack_overflow_);
  SaveState();

  __ mov(R1, R0);
  __ mov(R0, R4);
  __ bl("HandleStackOverflow");
  __ tst(R0, R0);
  __ b(NE, &stay_fast);
  __ mov(R0, Immediate(Interpreter::kInterrupt));
  __ b(&undo_padding);

  __ Bind(&stay_fast);
  RestoreState();
  Dispatch(0);
}

void InterpreterGeneratorARM::DoLoadLocal0() {
  LoadLocal(R0, 0);
  Push(R0);
  Dispatch(kLoadLocal0Length);
}

void InterpreterGeneratorARM::DoLoadLocal1() {
  LoadLocal(R0, 1);
  Push(R0);
  Dispatch(kLoadLocal1Length);
}

void InterpreterGeneratorARM::DoLoadLocal2() {
  LoadLocal(R0, 2);
  Push(R0);
  Dispatch(kLoadLocal2Length);
}

void InterpreterGeneratorARM::DoLoadLocal() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadBoxed() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadStatic() {
  __ ldr(R0, Address(R5, 1));
  __ ldr(R1, Address(R4, Process::StaticsOffset()));
  __ add(R1, R1, Immediate(Array::kSize - HeapObject::kTag));
  __ ldr(R0, Address(R1, Operand(R0, TIMES_4)));
  Push(R0);
  Dispatch(kLoadStaticLength);
}

void InterpreterGeneratorARM::DoLoadStaticInit() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadField() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadConst() {
  __ ldr(R0, Address(R5, 1));
  __ ldr(R1, Address(R4, Process::ProgramOffset()));
  __ ldr(R2, Address(R1, Program::ConstantsOffset()));
  __ add(R2, R2, Immediate(Array::kSize - HeapObject::kTag));
  __ ldr(R3, Address(R2, Operand(R0, TIMES_4)));
  Push(R3);
  Dispatch(kLoadConstLength);
}

void InterpreterGeneratorARM::DoLoadConstUnfold() {
  __ ldr(R0, Address(R5, 1));
  __ ldr(R2, Address(R5, Operand(R0, TIMES_1)));
  Push(R2);
  Dispatch(kLoadConstUnfoldLength);
}

void InterpreterGeneratorARM::DoStoreLocal() {
  LoadLocal(R1, 0);
  __ ldrb(R0, Address(R5, 1));
  __ neg(R0, R0);
  __ str(R1, Address(R6, Operand(R0, TIMES_4)));
  Dispatch(kStoreLocalLength);
}

void InterpreterGeneratorARM::DoStoreBoxed() {
  Bailout();
}

void InterpreterGeneratorARM::DoStoreStatic() {
  Bailout();
}

void InterpreterGeneratorARM::DoStoreField() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteralNull() {
  LoadNull(R0);
  Push(R0);
  Dispatch(kLoadLiteralNullLength);
}

void InterpreterGeneratorARM::DoLoadLiteralTrue() {
  LoadTrue(R0);
  Push(R0);
  Dispatch(kLoadLiteralTrueLength);
}

void InterpreterGeneratorARM::DoLoadLiteralFalse() {
  LoadFalse(R0);
  Push(R0);
  Dispatch(kLoadLiteralFalseLength);
}

void InterpreterGeneratorARM::DoLoadLiteral0() {
  __ mov(R0, Immediate(reinterpret_cast<int32_t>(Smi::FromWord(0))));
  Push(R0);
  Dispatch(kLoadLiteral0Length);
}

void InterpreterGeneratorARM::DoLoadLiteral1() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteral() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteralWide() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeMethod() {
  InvokeMethod(false);
}

void InterpreterGeneratorARM::DoInvokeTest() {
  InvokeMethod(true);
}

void InterpreterGeneratorARM::DoInvokeStatic() {
  InvokeStatic(false);
}

void InterpreterGeneratorARM::DoInvokeStaticUnfold() {
  InvokeStatic(true);
}

void InterpreterGeneratorARM::DoInvokeFactory() {
  InvokeStatic(false);
}

void InterpreterGeneratorARM::DoInvokeFactoryUnfold() {
  InvokeStatic(true);
}

void InterpreterGeneratorARM::DoInvokeNative() {
  InvokeNative(false);
}

void InterpreterGeneratorARM::DoInvokeNativeYield() {
  InvokeNative(true);
}

void InterpreterGeneratorARM::DoInvokeEq() {
  InvokeCompare(EQ);
}

void InterpreterGeneratorARM::DoInvokeLt() {
  InvokeCompare(LT);
}

void InterpreterGeneratorARM::DoInvokeLe() {
  InvokeCompare(LE);
}

void InterpreterGeneratorARM::DoInvokeGt() {
  InvokeCompare(GT);
}

void InterpreterGeneratorARM::DoInvokeGe() {
  InvokeCompare(GE);
}

void InterpreterGeneratorARM::DoInvokeAdd() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeSub() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeMod() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeMul() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeTruncDiv() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitNot() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitAnd() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitOr() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitXor() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitShr() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeBitShl() {
  Bailout();
}

void InterpreterGeneratorARM::DoPop() {
  Drop(1);
  Dispatch(kPopLength);
}

void InterpreterGeneratorARM::DoReturn() {
  // Get result from stack.
  LoadLocal(R0, 0);

  // Fetch the number of locals and arguments from the bytecodes.
  // Unfortunately, we have to negate the counts so we can use them
  // to index into the stack (grows towards higher addresses).
  __ ldrb(R1, Address(R5, 1));
  __ ldrb(R2, Address(R5, 2));
  __ neg(R1, R1);

  // Load the return address.
  __ ldr(R5, Address(R6, Operand(R1, TIMES_4)));

  // Drop both locals and arguments except one which we will overwrite
  // with the result (we've left the return address on the stack).
  __ sub(R1, R1, R2);
  __ add(R6, R6, Operand(R1, TIMES_4));

  // Overwrite the first argument (or the return address) with the result
  // and dispatch to the next bytecode.
  StoreLocal(R0, 0);
  Dispatch(0);
}

void InterpreterGeneratorARM::DoBranchLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchIfTrueLong() {
  Label branch;
  Pop(R7);
  LoadTrue(R0);
  __ cmp(R7, R0);
  __ b(EQ, &branch);
  Dispatch(kBranchIfTrueLongLength);

  __ Bind(&branch);
  __ ldr(R0, Address(R5, 1));
  __ add(R5, R5, R0);
  Dispatch(0);
}

void InterpreterGeneratorARM::DoBranchIfFalseLong() {
  Label branch;
  Pop(R7);
  LoadTrue(R0);
  __ cmp(R7, R0);
  __ b(NE, &branch);
  Dispatch(kBranchIfFalseLongLength);

  __ Bind(&branch);
  __ ldr(R0, Address(R5, 1));
  __ add(R5, R5, R0);
  Dispatch(0);
}

void InterpreterGeneratorARM::DoBranchBack() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchBackIfTrue() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchBackIfFalse() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchBackLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchBackIfTrueLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchBackIfFalseLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoAllocate() {
  Bailout();
}

void InterpreterGeneratorARM::DoAllocateUnfold() {
  Bailout();
}

void InterpreterGeneratorARM::DoAllocateBoxed() {
  Bailout();
}

void InterpreterGeneratorARM::DoNegate() {
  Bailout();
}

void InterpreterGeneratorARM::DoStackOverflowCheck() {
  Bailout();
}

void InterpreterGeneratorARM::DoThrow() {
  Bailout();
}

void InterpreterGeneratorARM::DoSubroutineCall() {
  Bailout();
}

void InterpreterGeneratorARM::DoSubroutineReturn() {
  Bailout();
}

void InterpreterGeneratorARM::DoProcessYield() {
  __ ldr(R1, Address(R4, Process::ProgramOffset()));
  __ ldr(R2, Address(R1, Program::true_object_offset()));
  __ ldr(R3, Address(R1, Program::null_object_offset()));

  Label done, yield;
  LoadLocal(R0, 0);
  __ cmp(R0, R2);
  __ b(NE, &yield);
  __ mov(R0, Immediate(Interpreter::kTerminate));
  __ b(&done);
  __ Bind(&yield);
  __ mov(R0, Immediate(Interpreter::kYield));

  __ Bind(&done);
  __ add(R5, R5, Immediate(kProcessYieldLength));
  StoreLocal(R3, 0);
  __ b(&done_);
}

void InterpreterGeneratorARM::DoCoroutineChange() {
  Bailout();
}

void InterpreterGeneratorARM::DoIdentical() {
  Bailout();
}

void InterpreterGeneratorARM::DoIdenticalNonNumeric() {
  LoadLocal(R0, 0);
  LoadLocal(R1, 1);

  Label true_case;
  __ cmp(R0, R1);
  __ b(EQ, &true_case);

  LoadFalse(R0);
  StoreLocal(R0, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);

  __ Bind(&true_case);
  LoadTrue(R0);
  StoreLocal(R0, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);
}

void InterpreterGeneratorARM::DoEnterNoSuchMethod() {
  Bailout();
}

void InterpreterGeneratorARM::DoExitNoSuchMethod() {
  Bailout();
}

void InterpreterGeneratorARM::DoFrameSize() {
  __ bkpt();
}

void InterpreterGeneratorARM::DoMethodEnd() {
  __ bkpt();
}

void InterpreterGeneratorARM::DoIntrinsicObjectEquals() {
  Bailout();
}

void InterpreterGeneratorARM::DoIntrinsicGetField() {
  Bailout();
}

void InterpreterGeneratorARM::DoIntrinsicSetField() {
  Bailout();
}

void InterpreterGeneratorARM::DoIntrinsicListIndexGet() {
  Bailout();
}

void InterpreterGeneratorARM::DoIntrinsicListIndexSet() {
  Bailout();
}

void InterpreterGeneratorARM::DoIntrinsicListLength() {
  Bailout();
}

void InterpreterGeneratorARM::Bailout() {
  __ mov(R0, Immediate(-1));
  __ b(&done_);
}

void InterpreterGeneratorARM::LoadTrue(Register reg) {
  // TODO(ager): Consider setting aside a register for this to avoid
  // memory trafic?
  __ ldr(reg, Address(R4, Process::ProgramOffset()));
  __ ldr(reg, Address(reg, Program::true_object_offset()));
}

void InterpreterGeneratorARM::LoadFalse(Register reg) {
  // TODO(ager): Consider setting aside a register for this to avoid
  // memory trafic?
  __ ldr(reg, Address(R4, Process::ProgramOffset()));
  __ ldr(reg, Address(reg, Program::false_object_offset()));
}

void InterpreterGeneratorARM::LoadNull(Register reg) {
  // TODO(ager): Consider setting aside a register for this to avoid
  // memory trafic?
  __ ldr(reg, Address(R4, Process::ProgramOffset()));
  __ ldr(reg, Address(reg, Program::null_object_offset()));
}

void InterpreterGeneratorARM::Push(Register reg) {
  StoreLocal(reg, -1);
  __ add(R6, R6, Immediate(1 * kWordSize));
}

void InterpreterGeneratorARM::Pop(Register reg) {
  LoadLocal(reg, 0);
  Drop(1);
}

void InterpreterGeneratorARM::LoadLocal(Register reg, int index) {
  __ ldr(reg, Address(R6, -index * kWordSize));
}

void InterpreterGeneratorARM::StoreLocal(Register reg, int index) {
  __ str(reg, Address(R6, -index * kWordSize));
}

void InterpreterGeneratorARM::Drop(int n) {
  __ sub(R6, R6, Immediate(n * kWordSize));
}

void InterpreterGeneratorARM::InvokeMethod(bool test) {
  if (!test) CheckStackOverflow(0);

  // Get the selector from the bytecodes.
  __ ldr(R7, Address(R5, 1));

  if (test) {
    // Get the receiver from the stack.
    LoadLocal(R1, 0);
  } else {
    // Compute the arity from the selector.
    ASSERT(Selector::ArityField::shift() == 0);
    __ and_(R2, R7, Immediate(Selector::ArityField::mask()));

    // Get the receiver from the stack.
    __ neg(R3, R2);
    __ ldr(R1, Address(R6, Operand(R3, TIMES_4)));
  }

  // Compute the receiver class.
  Label smi, probe;
  ASSERT(Smi::kTag == 0);
  __ tst(R1, Immediate(Smi::kTagMask));
  __ b(EQ, &smi);
  __ ldr(R2, Address(R1, HeapObject::kClassOffset - HeapObject::kTag));

  // Find the entry in the primary lookup cache.
  Label miss, finish;
  ASSERT(Utils::IsPowerOfTwo(LookupCache::kPrimarySize));
  ASSERT(sizeof(LookupCache::Entry) == 1 << 4);
  __ Bind(&probe);
  __ eor(R3, R2, R7);
  __ ldr(R0, Immediate(LookupCache::kPrimarySize - 1));
  __ and_(R0, R3, R0);
  __ lsl(R0, R0, Immediate(4));
  __ ldr(R3, Address(R4, Process::PrimaryLookupCacheOffset()));
  __ add(R0, R3, R0);

  // Validate the primary entry.
  __ ldr(R3, Address(R0, OFFSET_OF(LookupCache::Entry, clazz)));
  __ cmp(R2, R3);
  __ b(NE, &miss);
  __ ldr(R3, Address(R0, OFFSET_OF(LookupCache::Entry, selector)));
  __ cmp(R7, R3);
  __ b(NE, &miss);

  // At this point, we've got our hands on a valid lookup cache entry.
  Label intrinsified;
  __ Bind(&finish);
  if (test) {
    __ ldr(R0, Address(R0, OFFSET_OF(LookupCache::Entry, tag)));
  } else {
    __ ldr(R7, Address(R0, OFFSET_OF(LookupCache::Entry, tag)));
    __ ldr(R0, Address(R0, OFFSET_OF(LookupCache::Entry, target)));
    __ cmp(R7, Immediate(1));
    __ b(HI, &intrinsified);
  }

  if (test) {
    // Materialize either true or false depending on whether or not
    // we've found a target method.
    Label found;
    __ tst(R0, R0);
    __ b(NE, &found);

    LoadFalse(R0);
    StoreLocal(R0, 0);
    Dispatch(kInvokeTestLength);

    __ Bind(&found);
    LoadTrue(R0);
    StoreLocal(R0, 0);
    Dispatch(kInvokeTestLength);
  } else {
    // Compute and push the return address on the stack.
    __ add(R5, R5, Immediate(kInvokeMethodLength));
    Push(R5);

    // Jump to the first bytecode in the target method.
    __ add(R5, R0, Immediate(Function::kSize - HeapObject::kTag));
    Dispatch(0);
  }

  __ Bind(&smi);
  __ ldr(R3, Address(R4, Process::ProgramOffset()));
  __ ldr(R2, Address(R3, Program::smi_class_offset()));
  __ b(&probe);

  if (!test) {
    __ Bind(&intrinsified);
    __ mov(PC, R7);
  }

  // We didn't find a valid entry in primary lookup cache.
  __ Bind(&miss);
  // Arguments:
  // - r0: process
  // - r1: primary cache entry
  // - r2: class (already in r2)
  // - r3: selector
  __ mov(R1, R0);
  __ mov(R0, R4);
  __ mov(R3, R7);
  __ bl("HandleLookupEntry");
  __ b(&finish);
}

void InterpreterGeneratorARM::InvokeNative(bool yield) {
  __ ldrb(R1, Address(R5, 1));
  __ neg(R1, R1);
  __ ldrb(R0, Address(R5, 2));

  // Load native from native table.
  __ ldr(R8, "kNativeTable");
  __ ldr(R2, Address(R8, Operand(R0, TIMES_4)));

  // Setup argument (process and pointer to first argument).
  __ add(R7, R6, Operand(R1, TIMES_4));
  __ mov(R1, R7);
  __ mov(R0, R4);

  Label failure;
  __ blx(R2);
  __ and_(R1, R0, Immediate(Failure::kTagMask));
  __ cmp(R1, Immediate(Failure::kTag));
  __ b(EQ, &failure);

  // Result is in r0. Pointer to first argument is in r7. Load return address.
  LoadLocal(R5, 0);

  if (yield) {
    // TODO(ager): Implement.
    Bailout();
  } else {
    // Store the result in the stack and drop the arguments.
    __ str(R0, Address(R7, 0));
    __ mov(R6, R7);
  }

  // Dispatch to return address.
  Dispatch(0);

  // Failure: Check if it's a request to garbage collect. If not,
  // just continue running the failure block by dispatching to the
  // next bytecode.
  __ Bind(&failure);
  __ cmp(R0, Immediate(reinterpret_cast<int32>(Failure::retry_after_gc())));
  __ b(EQ, &gc_);

  // TODO(kasperl): This should be reworked. We shouldn't be calling
  // through the runtime system for something as simple as converting
  // a failure object to the corresponding heap object.
  __ mov(R1, R0);
  __ mov(R0, R4);
  __ bl("HandleObjectFromFailure");

  Push(R0);
  Dispatch(kInvokeNativeLength);
}

void InterpreterGeneratorARM::InvokeStatic(bool unfolded) {
  CheckStackOverflow(0);

  if (unfolded) {
    __ ldr(R1, Address(R5, 1));
    __ ldr(R0, Address(R5, Operand(R1, TIMES_1)));
  } else {
    __ ldr(R1, Address(R5, 1));
    __ ldr(R2, Address(R4, Process::ProgramOffset()));
    __ ldr(R3, Address(R2, Program::StaticMethodsOffset()));
    __ add(R3, R3, Immediate(Array::kSize - HeapObject::kTag));
    __ ldr(R0, Address(R3, Operand(R1, TIMES_4)));
  }

  // Compute and push the return address on the stack.
  __ add(R1, R5, Immediate(kInvokeStaticLength));
  Push(R1);

  // Jump to the first bytecode in the target method.
  __ add(R5, R0, Immediate(Function::kSize - HeapObject::kTag));
  Dispatch(0);
}

void InterpreterGeneratorARM::InvokeCompare(Condition cond) {
  LoadLocal(R0, 0);
  __ tst(R0, Immediate(Smi::kTagMask));
  __ b(NE, "BC_InvokeMethod");
  LoadLocal(R1, 1);
  __ tst(R1, Immediate(Smi::kTagMask));
  __ b(NE, "BC_InvokeMethod");

  Label true_case;
  __ cmp(R0, R1);
  __ b(cond, &true_case);

  LoadFalse(R0);
  StoreLocal(R0, 1);
  Drop(1);
  Dispatch(5);

  __ Bind(&true_case);
  LoadTrue(R0);
  StoreLocal(R0, 1);
  Drop(1);
  Dispatch(5);
}

void InterpreterGeneratorARM::CheckStackOverflow(int size) {
  __ ldr(R0, Address(R4, Process::StackLimitOffset()));
  __ cmp(R0, R6);
  if (size == 0) {
    __ mov(LS, R0, Immediate(0));
    __ b(LS, &check_stack_overflow_);
  } else {
    Label done;
    __ b(HI, &done);
    __ mov(R0, Immediate(size));
    __ b(&check_stack_overflow_);
    __ Bind(&done);
  }
}

void InterpreterGeneratorARM::Dispatch(int size) {
  // Load the next bytecode through R5 and dispatch to it.
  __ ldrb(R7, Address(R5, size));
  if (size > 0) {
    __ add(R5, R5, Immediate(size));
  }
  __ ldr(R8, "InterpretFast_DispatchTable");
  __ ldr(PC, Address(R8, Operand(R7, TIMES_4)));
  __ GenerateConstantPool();
}

void InterpreterGeneratorARM::SaveState() {
  // Push the bytecode pointer on the stack.
  Push(R5);

  // Update top in the stack. Ugh. Complicated.
  __ ldr(R7, Address(R4, Process::CoroutineOffset()));
  __ ldr(R8, Address(R7, Coroutine::kStackOffset - HeapObject::kTag));
  __ sub(R6, R6, R8);
  __ sub(R6, R6, Immediate(Stack::kSize - HeapObject::kTag));
  __ lsr(R6, R6, Immediate(1));
  __ str(R6, Address(R8, Stack::kTopOffset - HeapObject::kTag));
}

void InterpreterGeneratorARM::RestoreState() {
  // Load the current stack pointer into R6.
  __ ldr(R6, Address(R4, Process::CoroutineOffset()));
  __ ldr(R8, Address(R6, Coroutine::kStackOffset - HeapObject::kTag));
  __ ldr(R7, Address(R8, Stack::kTopOffset - HeapObject::kTag));
  __ add(R8, R8, Immediate(Stack::kSize - HeapObject::kTag));
  __ add(R6, R8, Operand(R7, TIMES_2));

  // Pop current bytecode pointer from the stack.
  Pop(R5);
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_ARM
