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
};

GENERATE(, InterpretFast) {
  InterpreterGeneratorARM generator(assembler);
  generator.Generate();
}

void InterpreterGeneratorARM::GeneratePrologue() {
  __ mov(R0, Immediate(-1));
  __ mov(PC, LR);
}

void InterpreterGeneratorARM::GenerateEpilogue() {
}

void InterpreterGeneratorARM::DoLoadLocal0() {
}

void InterpreterGeneratorARM::DoLoadLocal1() {
}

void InterpreterGeneratorARM::DoLoadLocal2() {
}

void InterpreterGeneratorARM::DoLoadLocal() {
}

void InterpreterGeneratorARM::DoLoadBoxed() {
}

void InterpreterGeneratorARM::DoLoadStatic() {
}

void InterpreterGeneratorARM::DoLoadStaticInit() {
}

void InterpreterGeneratorARM::DoLoadField() {
}

void InterpreterGeneratorARM::DoLoadConst() {
}

void InterpreterGeneratorARM::DoLoadConstUnfold() {
}

void InterpreterGeneratorARM::DoStoreLocal() {
}

void InterpreterGeneratorARM::DoStoreBoxed() {
}

void InterpreterGeneratorARM::DoStoreStatic() {
}

void InterpreterGeneratorARM::DoStoreField() {
}

void InterpreterGeneratorARM::DoLoadLiteralNull() {
}

void InterpreterGeneratorARM::DoLoadLiteralTrue() {
}

void InterpreterGeneratorARM::DoLoadLiteralFalse() {
}

void InterpreterGeneratorARM::DoLoadLiteral0() {
}

void InterpreterGeneratorARM::DoLoadLiteral1() {
}

void InterpreterGeneratorARM::DoLoadLiteral() {
}

void InterpreterGeneratorARM::DoLoadLiteralWide() {
}

void InterpreterGeneratorARM::DoInvokeMethod() {
}

void InterpreterGeneratorARM::DoInvokeTest() {
}

void InterpreterGeneratorARM::DoInvokeStatic() {
}

void InterpreterGeneratorARM::DoInvokeStaticUnfold() {
}

void InterpreterGeneratorARM::DoInvokeFactory() {
}

void InterpreterGeneratorARM::DoInvokeFactoryUnfold() {
}

void InterpreterGeneratorARM::DoInvokeNative() {
}

void InterpreterGeneratorARM::DoInvokeNativeYield() {
}

void InterpreterGeneratorARM::DoInvokeEq() {
}

void InterpreterGeneratorARM::DoInvokeLt() {
}

void InterpreterGeneratorARM::DoInvokeLe() {
}

void InterpreterGeneratorARM::DoInvokeGt() {
}

void InterpreterGeneratorARM::DoInvokeGe() {
}

void InterpreterGeneratorARM::DoInvokeAdd() {
}

void InterpreterGeneratorARM::DoInvokeSub() {
}

void InterpreterGeneratorARM::DoInvokeMod() {
}

void InterpreterGeneratorARM::DoInvokeMul() {
}

void InterpreterGeneratorARM::DoInvokeTruncDiv() {
}

void InterpreterGeneratorARM::DoInvokeBitNot() {
}

void InterpreterGeneratorARM::DoInvokeBitAnd() {
}

void InterpreterGeneratorARM::DoInvokeBitOr() {
}

void InterpreterGeneratorARM::DoInvokeBitXor() {
}

void InterpreterGeneratorARM::DoInvokeBitShr() {
}

void InterpreterGeneratorARM::DoInvokeBitShl() {
}

void InterpreterGeneratorARM::DoPop() {
}

void InterpreterGeneratorARM::DoReturn() {
}

void InterpreterGeneratorARM::DoBranchLong() {
}

void InterpreterGeneratorARM::DoBranchIfTrueLong() {
}

void InterpreterGeneratorARM::DoBranchIfFalseLong() {
}

void InterpreterGeneratorARM::DoBranchBack() {
}

void InterpreterGeneratorARM::DoBranchBackIfTrue() {
}

void InterpreterGeneratorARM::DoBranchBackIfFalse() {
}

void InterpreterGeneratorARM::DoBranchBackLong() {
}

void InterpreterGeneratorARM::DoBranchBackIfTrueLong() {
}

void InterpreterGeneratorARM::DoBranchBackIfFalseLong() {
}

void InterpreterGeneratorARM::DoAllocate() {
}

void InterpreterGeneratorARM::DoAllocateUnfold() {
}

void InterpreterGeneratorARM::DoAllocateBoxed() {
}

void InterpreterGeneratorARM::DoNegate() {
}

void InterpreterGeneratorARM::DoStackOverflowCheck() {
}

void InterpreterGeneratorARM::DoThrow() {
}

void InterpreterGeneratorARM::DoSubroutineCall() {
}

void InterpreterGeneratorARM::DoSubroutineReturn() {
}

void InterpreterGeneratorARM::DoProcessYield() {
}

void InterpreterGeneratorARM::DoCoroutineChange() {
}

void InterpreterGeneratorARM::DoIdentical() {
}

void InterpreterGeneratorARM::DoIdenticalNonNumeric() {
}

void InterpreterGeneratorARM::DoEnterNoSuchMethod() {
}

void InterpreterGeneratorARM::DoExitNoSuchMethod() {
}

void InterpreterGeneratorARM::DoFrameSize() {
  __ bkpt();
}

void InterpreterGeneratorARM::DoMethodEnd() {
  __ bkpt();
}

void InterpreterGeneratorARM::DoIntrinsicObjectEquals() {
}

void InterpreterGeneratorARM::DoIntrinsicGetField() {
}

void InterpreterGeneratorARM::DoIntrinsicSetField() {
}

void InterpreterGeneratorARM::DoIntrinsicListIndexGet() {
}

void InterpreterGeneratorARM::DoIntrinsicListIndexSet() {
}

void InterpreterGeneratorARM::DoIntrinsicListLength() {
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_ARM
