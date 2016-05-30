// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_MIPS)

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

namespace dartino {

class InterpreterGenerator {
 public:
  explicit InterpreterGenerator(Assembler* assembler)
      : assembler_(assembler) { }

  void Generate();

  virtual void GeneratePrologue() = 0;
  virtual void GenerateEpilogue() = 0;

  virtual void GenerateMethodEntry() = 0;

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

  GenerateMethodEntry();

  GenerateDebugAtBytecode();

#define V(name, branching, format, size, stack_diff, print) \
  GenerateBytecodePrologue("BC_" #name);                    \
  Do##name();
  BYTECODES_DO(V)
#undef V

#define V(name)           \
  __ AlignToPowerOfTwo(3);  \
  __ Bind("", "Intrinsic_" #name); \
  DoIntrinsic##name();
  INTRINSICS_DO(V)
#undef V

#define V(name, branching, format, size, stack_diff, print) \
  assembler()->DefineLong("BC_" #name);
  BYTECODES_DO(V)
#undef V

  __ SwitchToData();
  __ BindWithPowerOfTwoAlignment("Interpret_DispatchTable", 4);
#define V(name, branching, format, size, stack_diff, print) \
  assembler()->DefineLong("BC_" #name);
  BYTECODES_DO(V)
#undef V
}

class InterpreterGeneratorMIPS: public InterpreterGenerator {
 public:
  explicit InterpreterGeneratorMIPS(Assembler* assembler)
      : InterpreterGenerator(assembler) { }

  virtual void GeneratePrologue();
  virtual void GenerateEpilogue();

  virtual void GenerateMethodEntry();

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

  virtual void DoInvokeLeafNative();
  virtual void DoInvokeNative();
  virtual void DoInvokeNativeYield();

  virtual void DoInvokeTestUnfold();
  virtual void DoInvokeTest();

  virtual void DoInvokeSelector();

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
  Label done_state_saved_;
  Label check_stack_overflow_;
  Label check_stack_overflow_0_;
  Label gc_;
  Label intrinsic_failure_;
  Label interpreter_entry_;
  int spill_size_;

  void LoadLocal(Register reg, int index);
  void StoreLocal(Register reg, int index);

  void Push(Register reg);
  void Pop(Register reg);
  void Drop(int n);
  void Drop(Register reg);
  void DropNAndSetTop(int dropping_slots, Register reg);

  void LoadFramePointer(Register reg);
  void StoreFramePointer(Register reg);

  void SaveByteCodePointer(Register scratch);
  void RestoreByteCodePointer(Register scratch);

  void PushFrameDescriptor(Register return_address, Register scratch);
  void ReadFrameDescriptor(Register scratch);

  void Return(bool is_return_null);

  void Allocate(bool immutable);

  // This function trashes 'scratch'.
  void AddToRememberedSet(Register object, Register value, Register scratch);

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

  void InvokeBitNot(const char* fallback);
  void InvokeBitAnd(const char* fallback);
  void InvokeBitOr(const char* fallback);
  void InvokeBitXor(const char* fallback);
  void InvokeBitShr(const char* fallback);
  void InvokeBitShl(const char* fallback);

  void InvokeMethodUnfold(bool test);
  void InvokeMethod(bool test);

  void InvokeNative(bool yield, bool safepoint);
  void InvokeStatic();

  void ConditionalStore(Register cmp, Register reg_if_eq, Register reg_if_ne,
                        const Address& address);

  void CheckStackOverflow(int size);

  void Dispatch(int size);

  void SaveState(Label* resume);
  void RestoreState();

  static int ComputeStackPadding(int reserved, int extra) {
    const int kAlignment = 8;
    int rounded = (reserved + extra + kAlignment - 1) & ~(kAlignment - 1);
    return rounded - reserved;
  }
};

GENERATE(, Interpret) {
  InterpreterGeneratorMIPS generator(assembler);
  generator.Generate();
}

void InterpreterGeneratorMIPS::GeneratePrologue() {
}

void InterpreterGeneratorMIPS::GenerateEpilogue() {
  // Default entrypoint.
  __ Bind("", "InterpreterEntry");
  __ Bind(&interpreter_entry_);
  Dispatch(0);

  /* ... */
}

void InterpreterGeneratorMIPS::GenerateMethodEntry() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(3);
  __ Bind("", "InterpreterMethodEntry");

  /* ... */
}

void InterpreterGeneratorMIPS::GenerateBytecodePrologue(const char* name) {
  __ SwitchToText();
  __ AlignToPowerOfTwo(3);
  __ nop();
  __ nop();
  __ nop();
  __ nop();
  __ nop();
  __ Bind("Debug_", name);
  __ la(T9, "DebugAtBytecode");
  __ jalr(T9);
  __ nop();
  __ AlignToPowerOfTwo(3);
  __ Bind("", name);
}

void InterpreterGeneratorMIPS::GenerateDebugAtBytecode() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(4);  // Align to 8-byte storage boundary.
  __ Bind("", "DebugAtBytecode");
}

void InterpreterGeneratorMIPS::DoLoadLocal0() {
}

void InterpreterGeneratorMIPS::DoLoadLocal1() {
}

void InterpreterGeneratorMIPS::DoLoadLocal2() {
}

void InterpreterGeneratorMIPS::DoLoadLocal3() {
}

void InterpreterGeneratorMIPS::DoLoadLocal4() {
}

void InterpreterGeneratorMIPS::DoLoadLocal5() {
}

void InterpreterGeneratorMIPS::DoLoadLocal() {
}

void InterpreterGeneratorMIPS::DoLoadLocalWide() {
}

void InterpreterGeneratorMIPS::DoLoadBoxed() {
}

void InterpreterGeneratorMIPS::DoLoadStatic() {
}

void InterpreterGeneratorMIPS::DoLoadStaticInit() {
}

void InterpreterGeneratorMIPS::DoLoadField() {
}

void InterpreterGeneratorMIPS::DoLoadFieldWide() {
}

void InterpreterGeneratorMIPS::DoLoadConst() {
}

void InterpreterGeneratorMIPS::DoStoreLocal() {
}

void InterpreterGeneratorMIPS::DoStoreBoxed() {
}

void InterpreterGeneratorMIPS::DoStoreStatic() {
}

void InterpreterGeneratorMIPS::DoStoreField() {
}

void InterpreterGeneratorMIPS::DoStoreFieldWide() {
}

void InterpreterGeneratorMIPS::DoLoadLiteralNull() {
}

void InterpreterGeneratorMIPS::DoLoadLiteralTrue() {
}

void InterpreterGeneratorMIPS::DoLoadLiteralFalse() {
}

void InterpreterGeneratorMIPS::DoLoadLiteral0() {
}

void InterpreterGeneratorMIPS::DoLoadLiteral1() {
}

void InterpreterGeneratorMIPS::DoLoadLiteral() {
}

void InterpreterGeneratorMIPS::DoLoadLiteralWide() {
}

void InterpreterGeneratorMIPS::DoInvokeMethodUnfold() {
}

void InterpreterGeneratorMIPS::DoInvokeMethod() {
}

void InterpreterGeneratorMIPS::DoInvokeNoSuchMethod() {
}

void InterpreterGeneratorMIPS::DoInvokeTestNoSuchMethod() {
}

void InterpreterGeneratorMIPS::DoInvokeTestUnfold() {
}

void InterpreterGeneratorMIPS::DoInvokeTest() {
}

void InterpreterGeneratorMIPS::DoInvokeStatic() {
}

void InterpreterGeneratorMIPS::DoInvokeFactory() {
}

void InterpreterGeneratorMIPS::DoInvokeLeafNative() {
}

void InterpreterGeneratorMIPS::DoInvokeNative() {
}

void InterpreterGeneratorMIPS::DoInvokeNativeYield() {
}

void InterpreterGeneratorMIPS::DoInvokeSelector() {
}

void InterpreterGeneratorMIPS::InvokeEq(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeLt(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeLe(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeGt(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeGe(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeAdd(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeSub(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeMod(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeMul(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeTruncDiv(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitNot(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitAnd(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitOr(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitXor(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitShr(const char* fallback) {
}

void InterpreterGeneratorMIPS::InvokeBitShl(const char* fallback) {
}

void InterpreterGeneratorMIPS::DoPop() {
}

void InterpreterGeneratorMIPS::DoDrop() {
}

void InterpreterGeneratorMIPS::DoReturn() {
}

void InterpreterGeneratorMIPS::DoReturnNull() {
}

void InterpreterGeneratorMIPS::DoBranchWide() {
}

void InterpreterGeneratorMIPS::DoBranchIfTrueWide() {
}

void InterpreterGeneratorMIPS::DoBranchIfFalseWide() {
}

void InterpreterGeneratorMIPS::DoBranchBack() {
}

void InterpreterGeneratorMIPS::DoBranchBackIfTrue() {
}

void InterpreterGeneratorMIPS::DoBranchBackIfFalse() {
}

void InterpreterGeneratorMIPS::DoBranchBackWide() {
}

void InterpreterGeneratorMIPS::DoBranchBackIfTrueWide() {
}

void InterpreterGeneratorMIPS::DoBranchBackIfFalseWide() {
}

void InterpreterGeneratorMIPS::DoPopAndBranchWide() {
}

void InterpreterGeneratorMIPS::DoPopAndBranchBackWide() {
}

void InterpreterGeneratorMIPS::DoAllocate() {
}

void InterpreterGeneratorMIPS::DoAllocateImmutable() {
}

void InterpreterGeneratorMIPS::DoAllocateBoxed() {
}

void InterpreterGeneratorMIPS::DoNegate() {
}

void InterpreterGeneratorMIPS::DoStackOverflowCheck() {
}

void InterpreterGeneratorMIPS::DoThrowAfterSaveState(Label* resume) {
}

void InterpreterGeneratorMIPS::DoThrow() {
}

void InterpreterGeneratorMIPS::DoSubroutineCall() {
}

void InterpreterGeneratorMIPS::DoSubroutineReturn() {
}

void InterpreterGeneratorMIPS::DoProcessYield() {
}

void InterpreterGeneratorMIPS::DoCoroutineChange() {
}

void InterpreterGeneratorMIPS::DoIdentical() {
}

void InterpreterGeneratorMIPS::DoIdenticalNonNumeric() {
}

void InterpreterGeneratorMIPS::DoEnterNoSuchMethod() {
}

void InterpreterGeneratorMIPS::DoExitNoSuchMethod() {
}

void InterpreterGeneratorMIPS::DoMethodEnd() {
}

void InterpreterGeneratorMIPS::DoIntrinsicObjectEquals() {
}

void InterpreterGeneratorMIPS::DoIntrinsicGetField() {
}

void InterpreterGeneratorMIPS::DoIntrinsicSetField() {
}

void InterpreterGeneratorMIPS::DoIntrinsicListIndexGet() {
}

void InterpreterGeneratorMIPS::DoIntrinsicListIndexSet() {
}

void InterpreterGeneratorMIPS::DoIntrinsicListLength() {
}

void InterpreterGeneratorMIPS::Push(Register reg) {
}

void InterpreterGeneratorMIPS::Return(bool is_return_null) {
}

void InterpreterGeneratorMIPS::LoadLocal(Register reg, int index) {
}

void InterpreterGeneratorMIPS::StoreLocal(Register reg, int index) {
}

void InterpreterGeneratorMIPS::Drop(int n) {
}

void InterpreterGeneratorMIPS::Drop(Register reg) {
}

void InterpreterGeneratorMIPS::DropNAndSetTop(int dropping_slots,
                                              Register reg) {
}

void InterpreterGeneratorMIPS::LoadFramePointer(Register reg) {
}

void InterpreterGeneratorMIPS::StoreFramePointer(Register reg) {
}

void InterpreterGeneratorMIPS::SaveByteCodePointer(Register scratch) {
}

void InterpreterGeneratorMIPS::RestoreByteCodePointer(Register scratch) {
}

void InterpreterGeneratorMIPS::PushFrameDescriptor(Register return_address,
                                                   Register scratch) {
}

void InterpreterGeneratorMIPS::ReadFrameDescriptor(Register scratch) {
}

void InterpreterGeneratorMIPS::InvokeMethodUnfold(bool test) {
}

void InterpreterGeneratorMIPS::InvokeMethod(bool test) {
}

void InterpreterGeneratorMIPS::InvokeNative(bool yield, bool safepoint) {
}

void InterpreterGeneratorMIPS::InvokeStatic() {
}

void InterpreterGeneratorMIPS::Allocate(bool immutable) {
}

void InterpreterGeneratorMIPS::AddToRememberedSet(Register object,
                                                  Register value,
                                                  Register scratch) {
}

void InterpreterGeneratorMIPS::InvokeCompare(const char* fallback,
                                             Condition cond) {
}

void InterpreterGeneratorMIPS::ConditionalStore(Register cmp,
                                                Register reg_if_eq,
                                                Register reg_if_ne,
                                                const Address& address) {
}

void InterpreterGeneratorMIPS::CheckStackOverflow(int size) {
}

void InterpreterGeneratorMIPS::Dispatch(int size) {
}

void InterpreterGeneratorMIPS::SaveState(Label* resume) {
}

void InterpreterGeneratorMIPS::RestoreState() {
}
}  // namespace dartino
#endif  // defined DARTINO_TARGET_MIPS
