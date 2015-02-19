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

  void Bailout();

  void LoadLocal(Register reg, int index);
  void StoreLocal(Register reg, int index);

  void Push(Register reg);
  void Pop(Register reg);
  void Drop(int n);

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
  __ push(RegisterRange(R4, R11));

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
  int padding = ComputeStackPadding(8 * kWordSize, 0);
  if (padding > 0) __ add(SP, SP, Immediate(padding));

  // Restore callee-saved registers and return.
  __ pop(RegisterRange(R4, R11));
  __ mov(PC, LR);
}

void InterpreterGeneratorARM::DoLoadLocal0() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLocal1() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLocal2() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLocal() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadBoxed() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadStatic() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadStaticInit() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadField() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadConst() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadConstUnfold() {
  Bailout();
}

void InterpreterGeneratorARM::DoStoreLocal() {
  Bailout();
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
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteralTrue() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteralFalse() {
  Bailout();
}

void InterpreterGeneratorARM::DoLoadLiteral0() {
  Bailout();
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
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeTest() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeStatic() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeStaticUnfold() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeFactory() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeFactoryUnfold() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeNative() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeNativeYield() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeEq() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeLt() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeLe() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeGt() {
  Bailout();
}

void InterpreterGeneratorARM::DoInvokeGe() {
  Bailout();
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
  Bailout();
}

void InterpreterGeneratorARM::DoReturn() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchIfTrueLong() {
  Bailout();
}

void InterpreterGeneratorARM::DoBranchIfFalseLong() {
  Bailout();
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
  Bailout();
}

void InterpreterGeneratorARM::DoCoroutineChange() {
  Bailout();
}

void InterpreterGeneratorARM::DoIdentical() {
  Bailout();
}

void InterpreterGeneratorARM::DoIdenticalNonNumeric() {
  Bailout();
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

void InterpreterGeneratorARM::Dispatch(int size) {
  // Load the next bytecode through R5 and dispatch to it.
  __ ldrb(R7, Address(R5, size));
  if (size > 0) {
    __ add(R5, R5, Immediate(size));
  }
  __ adr(R8, "InterpretFast_DispatchTable");
  __ ldr(PC, Address(R8, Operand(R7, TIMES_4)));
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
