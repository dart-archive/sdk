// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_X64)

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
  explicit InterpreterGenerator(Assembler* assembler) : assembler_(assembler) {}

  void Generate();

  virtual void GeneratePrologue() = 0;
  virtual void GenerateEpilogue() = 0;

  virtual void GenerateBytecodePrologue(const char* name) = 0;
  virtual void GenerateDebugAtBytecode() = 0;

#define V(name, branching, format, size, stack_diff, print) \
  virtual void Do##name() = 0;
  BYTECODES_DO(V)
#undef V

#define V(name) virtual void DoIntrinsic##name() = 0;
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

  GenerateDebugAtBytecode();

#define V(name, branching, format, size, stack_diff, print) \
  GenerateBytecodePrologue("BC_" #name);                    \
  Do##name();
  BYTECODES_DO(V)
#undef V

#define V(name)                              \
  assembler()->Bind("", "Intrinsic_" #name); \
  DoIntrinsic##name();
  INTRINSICS_DO(V)
#undef V

  assembler()->SwitchToData();
  assembler()->BindWithPowerOfTwoAlignment("InterpretFast_DispatchTable", 4);
#define V(name, branching, format, size, stack_diff, print) \
  assembler()->DefineLong("BC_" #name);
  BYTECODES_DO(V)
#undef V

  puts("\n");
}

class InterpreterGeneratorX86 : public InterpreterGenerator {
 public:
  explicit InterpreterGeneratorX86(Assembler* assembler)
      : InterpreterGenerator(assembler), spill_size_(-1) {}

  // Registers
  // ---------
  //   edi: stack pointer (top)
  //   esi: bytecode pointer
  //   ebp: <reserved>
  //

  virtual void GeneratePrologue();
  virtual void GenerateEpilogue();

  virtual void GenerateBytecodePrologue(const char* name);
  virtual void GenerateDebugAtBytecode();

  virtual void DoLoadLocal0();
  virtual void DoLoadLocal1();
  virtual void DoLoadLocal2();
  virtual void DoLoadLocal3();
  virtual void DoLoadLocal4();
  virtual void DoLoadLocal5();
  virtual void DoLoadLocal();
  virtual void DoLoadLocalWide();

  virtual void DoLoadBoxed();
  virtual void DoLoadStatic();
  virtual void DoLoadStaticInit();
  virtual void DoLoadField();
  virtual void DoLoadFieldWide();

  virtual void DoLoadConst();

  virtual void DoStoreLocal();
  virtual void DoStoreBoxed();
  virtual void DoStoreStatic();
  virtual void DoStoreField();
  virtual void DoStoreFieldWide();

  virtual void DoLoadLiteralNull();
  virtual void DoLoadLiteralTrue();
  virtual void DoLoadLiteralFalse();
  virtual void DoLoadLiteral0();
  virtual void DoLoadLiteral1();
  virtual void DoLoadLiteral();
  virtual void DoLoadLiteralWide();

  virtual void DoInvokeMethodUnfold();
  virtual void DoInvokeMethod();

  virtual void DoInvokeNoSuchMethod();
  virtual void DoInvokeTestNoSuchMethod();

  virtual void DoInvokeStatic();
  virtual void DoInvokeFactory();

  virtual void DoInvokeNative();
  virtual void DoInvokeNativeYield();

  virtual void DoInvokeSelector();

  virtual void DoInvokeTestUnfold();
  virtual void DoInvokeTest();

#define INVOKE_BUILTIN(kind)               \
  virtual void DoInvoke##kind##Unfold() {  \
    Invoke##kind("BC_InvokeMethodUnfold"); \
  }                                        \
  virtual void DoInvoke##kind() { Invoke##kind("BC_InvokeMethod"); }

  INVOKE_BUILTIN(Eq);
  INVOKE_BUILTIN(Lt);
  INVOKE_BUILTIN(Le);
  INVOKE_BUILTIN(Gt);
  INVOKE_BUILTIN(Ge);

  INVOKE_BUILTIN(Add);
  INVOKE_BUILTIN(Sub);
  INVOKE_BUILTIN(Mod);
  INVOKE_BUILTIN(Mul);
  INVOKE_BUILTIN(TruncDiv);

  INVOKE_BUILTIN(BitNot);
  INVOKE_BUILTIN(BitAnd);
  INVOKE_BUILTIN(BitOr);
  INVOKE_BUILTIN(BitXor);
  INVOKE_BUILTIN(BitShr);
  INVOKE_BUILTIN(BitShl);

#undef INVOKE_BUILTIN

  virtual void DoPop();
  virtual void DoDrop();
  virtual void DoReturn();
  virtual void DoReturnNull();

  virtual void DoBranchWide();
  virtual void DoBranchIfTrueWide();
  virtual void DoBranchIfFalseWide();

  virtual void DoBranchBack();
  virtual void DoBranchBackIfTrue();
  virtual void DoBranchBackIfFalse();

  virtual void DoBranchBackWide();
  virtual void DoBranchBackIfTrueWide();
  virtual void DoBranchBackIfFalseWide();

  virtual void DoPopAndBranchWide();
  virtual void DoPopAndBranchBackWide();

  virtual void DoAllocate();
  virtual void DoAllocateImmutable();
  virtual void DoAllocateBoxed();

  virtual void DoNegate();

  virtual void DoStackOverflowCheck();

  virtual void DoThrow();
  // Expects to be called after SaveState with the exception object in EBX.
  virtual void DoThrowAfterSaveState(Label* resume);
  virtual void DoSubroutineCall();
  virtual void DoSubroutineReturn();

  virtual void DoProcessYield();
  virtual void DoCoroutineChange();

  virtual void DoIdentical();
  virtual void DoIdenticalNonNumeric();

  virtual void DoEnterNoSuchMethod();
  virtual void DoExitNoSuchMethod();

  virtual void DoMethodEnd();

  virtual void DoIntrinsicObjectEquals();
  virtual void DoIntrinsicGetField();
  virtual void DoIntrinsicSetField();
  virtual void DoIntrinsicListIndexGet();
  virtual void DoIntrinsicListIndexSet();
  virtual void DoIntrinsicListLength();

 private:
  Label done_;
  Label gc_;
  Label check_stack_overflow_;
  Label check_stack_overflow_0_;
  Label intrinsic_failure_;
  Label interpreter_entry_;
  int spill_size_;

  void LoadLocal(Register reg, int index);
  void StoreLocal(Register reg, int index);
  void StoreLocal(const Immediate& value, int index);

  void Push(Register reg);
  void Push(const Immediate& value);
  void Pop(Register reg);
  void Drop(int n);
  void Drop(Register reg);

  void LoadProcess(Register reg);
  void LoadProgram(Register reg);
  void LoadStaticsArray(Register reg);
  void LoadLiteralNull(Register reg);
  void LoadLiteralTrue(Register reg);
  void LoadLiteralFalse(Register reg);

  void SwitchToDartStack();
  void SwitchToCStack();

  void PushFrameDescriptor(Register bcp, Register scratch);
  void ReadFrameDescriptor(Register scratch);

  void Return(bool is_return_null);

  void Allocate(bool immutable);

  // This function
  //   * changes the first three stack slots
  //   * changes caller-saved registers
  void AddToStoreBufferSlow(Register object, Register value, Register scratch);

  void InvokeMethodUnfold(bool test);
  void InvokeMethod(bool test);

  void InvokeStatic();

  void InvokeEq(const char* fallback);
  void InvokeLt(const char* fallback);
  void InvokeLe(const char* fallback);
  void InvokeGt(const char* fallback);
  void InvokeGe(const char* fallback);
  void InvokeCompare(const char* fallback, Condition condition);

  void InvokeAdd(const char* fallback);
  void InvokeSub(const char* fallback);
  void InvokeMod(const char* fallback);
  void InvokeMul(const char* fallback);
  void InvokeTruncDiv(const char* fallback);
  void InvokeDivision(const char* fallback, bool quotient);

  void InvokeBitNot(const char* fallback);
  void InvokeBitAnd(const char* fallback);
  void InvokeBitOr(const char* fallback);
  void InvokeBitXor(const char* fallback);
  void InvokeBitShr(const char* fallback);
  void InvokeBitShl(const char* fallback);

  void InvokeNative(bool yield);

  void CheckStackOverflow(int size);

  void Dispatch(int size);

  void SaveState(Label* resume);
  void RestoreState();

  static int ComputeStackPadding(int reserved, int extra) {
    const int kAlignment = 16;
    int rounded = (reserved + extra + kAlignment - 1) & ~(kAlignment - 1);
    return rounded - reserved;
  }
};

GENERATE(, InterpretFast) {
  InterpreterGeneratorX86 generator(assembler);
  generator.Generate();
}

void InterpreterGeneratorX86::GeneratePrologue() {
  __ int3();
}

void InterpreterGeneratorX86::GenerateEpilogue() {
  __ Bind("", "InterpreterEntry");
  __ int3();
}

void InterpreterGeneratorX86::GenerateBytecodePrologue(const char* name) {
  __ SwitchToText();
  __ AlignToPowerOfTwo(3);
  __ nop();
  __ nop();
  __ nop();
  __ nop();
  __ Bind("Debug_", name);
  __ call("DebugAtBytecode");
  __ AlignToPowerOfTwo(3);
  __ Bind("", name);
}

void InterpreterGeneratorX86::GenerateDebugAtBytecode() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(4);
  __ Bind("", "DebugAtBytecode");
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal0() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal1() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal2() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal3() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal4() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal5() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocal() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLocalWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadBoxed() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadStatic() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadStaticInit() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadField() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadFieldWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadConst() {
  __ int3();
}

void InterpreterGeneratorX86::DoStoreLocal() {
  __ int3();
}

void InterpreterGeneratorX86::DoStoreBoxed() {
  __ int3();
}

void InterpreterGeneratorX86::DoStoreStatic() {
  __ int3();
}

void InterpreterGeneratorX86::DoStoreField() {
  __ int3();
}

void InterpreterGeneratorX86::DoStoreFieldWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteralNull() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteralTrue() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteralFalse() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteral0() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteral1() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteral() {
  __ int3();
}

void InterpreterGeneratorX86::DoLoadLiteralWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoInvokeMethodUnfold() {
  InvokeMethodUnfold(false);
}

void InterpreterGeneratorX86::DoInvokeMethod() { InvokeMethod(false); }

void InterpreterGeneratorX86::DoInvokeNoSuchMethod() {
  __ int3();
}

void InterpreterGeneratorX86::DoInvokeTestNoSuchMethod() {
  __ int3();
}

void InterpreterGeneratorX86::DoInvokeTestUnfold() { InvokeMethodUnfold(true); }

void InterpreterGeneratorX86::DoInvokeTest() { InvokeMethod(true); }

void InterpreterGeneratorX86::DoInvokeStatic() { InvokeStatic(); }

void InterpreterGeneratorX86::DoInvokeFactory() { InvokeStatic(); }

void InterpreterGeneratorX86::DoInvokeNative() { InvokeNative(false); }

void InterpreterGeneratorX86::DoInvokeNativeYield() { InvokeNative(true); }

void InterpreterGeneratorX86::DoInvokeSelector() {
  __ int3();
}

void InterpreterGeneratorX86::InvokeEq(const char* fallback) {
  InvokeCompare(fallback, EQUAL);
}

void InterpreterGeneratorX86::InvokeLt(const char* fallback) {
  InvokeCompare(fallback, LESS);
}

void InterpreterGeneratorX86::InvokeLe(const char* fallback) {
  InvokeCompare(fallback, LESS_EQUAL);
}

void InterpreterGeneratorX86::InvokeGt(const char* fallback) {
  InvokeCompare(fallback, GREATER);
}

void InterpreterGeneratorX86::InvokeGe(const char* fallback) {
  InvokeCompare(fallback, GREATER_EQUAL);
}

void InterpreterGeneratorX86::InvokeAdd(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeSub(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeMod(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeMul(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeTruncDiv(const char* fallback) {
  InvokeDivision(fallback, true);
}

void InterpreterGeneratorX86::InvokeBitNot(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeBitAnd(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeBitOr(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeBitXor(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeBitShr(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeBitShl(const char* fallback) {
  __ int3();
}

void InterpreterGeneratorX86::DoPop() {
  Drop(1);
  Dispatch(kPopLength);
}

void InterpreterGeneratorX86::DoDrop() {
  __ int3();
}

void InterpreterGeneratorX86::DoReturn() { Return(false); }

void InterpreterGeneratorX86::DoReturnNull() { Return(true); }

void InterpreterGeneratorX86::DoBranchWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchIfTrueWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchIfFalseWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBack() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBackIfTrue() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBackIfFalse() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBackWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBackIfTrueWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoBranchBackIfFalseWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoPopAndBranchWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoPopAndBranchBackWide() {
  __ int3();
}

void InterpreterGeneratorX86::DoAllocate() { Allocate(false); }

void InterpreterGeneratorX86::DoAllocateImmutable() { Allocate(true); }

void InterpreterGeneratorX86::DoAllocateBoxed() {
  __ int3();
}

void InterpreterGeneratorX86::DoNegate() {
  __ int3();
}

void InterpreterGeneratorX86::DoStackOverflowCheck() {
  __ int3();
}

void InterpreterGeneratorX86::DoThrow() {
  __ int3();
}

void InterpreterGeneratorX86::DoThrowAfterSaveState(Label* resume) {
  __ int3();
}

void InterpreterGeneratorX86::DoSubroutineCall() {
  __ int3();
}

void InterpreterGeneratorX86::DoSubroutineReturn() {
  __ int3();
}

void InterpreterGeneratorX86::DoProcessYield() {
  __ int3();
}

void InterpreterGeneratorX86::DoCoroutineChange() {
  __ Bind("", "InterpreterCoroutineEntry");
  __ int3();
}

void InterpreterGeneratorX86::DoIdentical() {
  __ int3();
}

void InterpreterGeneratorX86::DoIdenticalNonNumeric() {
  __ int3();
}

void InterpreterGeneratorX86::DoEnterNoSuchMethod() {
  __ int3();
}

void InterpreterGeneratorX86::DoExitNoSuchMethod() {
  __ int3();
}

void InterpreterGeneratorX86::DoMethodEnd() { __ int3(); }

void InterpreterGeneratorX86::DoIntrinsicObjectEquals() {
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicGetField() {
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicSetField() {
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicListIndexGet() {
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicListIndexSet() {
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicListLength() {
  __ int3();
}

void InterpreterGeneratorX86::Push(Register reg) { __ int3(); }

void InterpreterGeneratorX86::Push(const Immediate& value) { __ int3(); }

void InterpreterGeneratorX86::Pop(Register reg) { __ int3(); }

void InterpreterGeneratorX86::Drop(int n) {
  __ int3();
}

void InterpreterGeneratorX86::Drop(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadProcess(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadProgram(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadStaticsArray(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadLiteralNull(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadLiteralTrue(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::LoadLiteralFalse(Register reg) {
  __ int3();
}

void InterpreterGeneratorX86::SwitchToDartStack() {
  __ int3();
}

void InterpreterGeneratorX86::SwitchToCStack() {
  __ int3();
}

void InterpreterGeneratorX86::PushFrameDescriptor(Register bcp,
                                                  Register scratch) {
  __ int3();
}

void InterpreterGeneratorX86::ReadFrameDescriptor(Register scratch) {
  __ int3();
}

void InterpreterGeneratorX86::LoadLocal(Register reg, int index) {
  __ int3();
}

void InterpreterGeneratorX86::StoreLocal(Register reg, int index) {
  __ int3();
}

void InterpreterGeneratorX86::StoreLocal(const Immediate& value, int index) {
  __ int3();
}

void InterpreterGeneratorX86::Return(bool is_return_null) {
  __ int3();
}

void InterpreterGeneratorX86::Allocate(bool immutable) {
  __ int3();
}

void InterpreterGeneratorX86::AddToStoreBufferSlow(Register object,
                                                   Register value,
                                                   Register scratch) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeMethodUnfold(bool test) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeMethod(bool test) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeStatic() {
  __ int3();
}

void InterpreterGeneratorX86::InvokeCompare(const char* fallback,
                                            Condition condition) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeDivision(const char* fallback,
                                             bool quotient) {
  __ int3();
}

void InterpreterGeneratorX86::InvokeNative(bool yield) {
  // TODO(ager): Get rid of this, used to silence compiler until we actually use
  // spill_size_.
  USE(spill_size_);
  __ int3();
}

void InterpreterGeneratorX86::CheckStackOverflow(int size) {
  __ int3();
}

void InterpreterGeneratorX86::Dispatch(int size) {
  __ int3();
}

void InterpreterGeneratorX86::SaveState(Label* resume) {
  __ int3();
}

void InterpreterGeneratorX86::RestoreState() {
  __ int3();
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_X64
