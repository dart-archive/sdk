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

  // Registers
  // ---------
  // s0: current process
  // s1: bytecode pointer
  // s2: stack pointer
  // s4: null
  // s6: true
  // s7: false

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
  // Used in GeneratePrologue/Epilogue, S0-S7 + RA + FP.
  static const int kSaveFrameSize = 10;

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

  void ShiftAddJump(Register reg1, Register reg2, int imm);
  void PrepareStack();
  void RestoreStack();

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
  // Push callee-saved registers and reserve one extra slot.
  __ addiu(SP, SP, Immediate(-kSaveFrameSize * kWordSize));
  __ sw(S0, Address(SP, 9 * kWordSize));
  __ sw(S1, Address(SP, 8 * kWordSize));
  __ sw(S2, Address(SP, 7 * kWordSize));
  __ sw(S3, Address(SP, 6 * kWordSize));
  __ sw(S4, Address(SP, 5 * kWordSize));
  __ sw(S5, Address(SP, 4 * kWordSize));
  __ sw(S6, Address(SP, 3 * kWordSize));
  __ sw(S7, Address(SP, 2 * kWordSize));
  __ sw(RA, Address(SP, 1 * kWordSize));

  // Setup process pointer in S0
  __ move(S0, A0);

  // Pad the stack to guarantee the right alignment for calls.
  spill_size_ = ComputeStackPadding(kSaveFrameSize * kWordSize, 1 * kWordSize);
  if (spill_size_ > 0) __ addiu(SP, SP, Immediate(-1 * spill_size_));

  // Store the argument target yield address in the extra slot on the
  // top of the stack.
  __ sw(A1, Address(SP, 0));

  // Restore the register state and dispatch to the first bytecode.
  RestoreState();
}

void InterpreterGeneratorMIPS::GenerateEpilogue() {
  // Done. Save the register state.
  __ Bind(&done_);
  SaveState(&interpreter_entry_);

  // Undo stack padding.
  __ Bind(&done_state_saved_);
  if (spill_size_ > 0) __ addiu(SP, SP, Immediate(spill_size_));

  // Restore callee-saved registers and return.
  __ lw(RA, Address(SP, 1 * kWordSize));
  __ lw(S7, Address(SP, 2 * kWordSize));
  __ lw(S6, Address(SP, 3 * kWordSize));
  __ lw(S5, Address(SP, 4 * kWordSize));
  __ lw(S4, Address(SP, 5 * kWordSize));
  __ lw(S3, Address(SP, 6 * kWordSize));
  __ lw(S2, Address(SP, 7 * kWordSize));
  __ lw(S1, Address(SP, 8 * kWordSize));
  __ lw(S0, Address(SP, 9 * kWordSize));

  __ jr(RA);
  __ addiu(SP, SP, Immediate(kSaveFrameSize * kWordSize));  // Delay-slot.

  // Default entrypoint.
  __ Bind("", "InterpreterEntry");
  __ Bind(&interpreter_entry_);
  Dispatch(0);

  // Handle GC and re-interpret current bytecode.
  __ Bind(&gc_);
  SaveState(&interpreter_entry_);
  PrepareStack();
  __ la(T9, "HandleGC");
  __ jalr(T9);
  __ move(A0, S0);  // Delay-slot.
  RestoreStack();
  RestoreState();

  // Stack overflow handling (slow case).
  Label stay_fast, overflow, check_debug_interrupt, overflow_resume;
  __ Bind(&check_stack_overflow_0_);
  __ move(A0, ZR);
  __ Bind(&check_stack_overflow_);
  SaveState(&overflow_resume);

  __ move(A1, A0);
  PrepareStack();
  __ la(T9, "HandleStackOverflow");
  __ jalr(T9);
  __ move(A0, S0);  // Delay-slot.
  RestoreStack();
  RestoreState();
  __ Bind(&overflow_resume);
  ASSERT(Process::kStackCheckContinue == 0);
  __ B(EQ, V0, ZR, &stay_fast);
  __ li(T0, Immediate(Process::kStackCheckInterrupt));
  __ B(NEQ, V0, T0, &check_debug_interrupt);
  __ b(&done_);
  __ ori(V0, ZR, Immediate(Interpreter::kInterrupt));  // Delay-slot.
  __ Bind(&check_debug_interrupt);
  __ li(T0, Immediate(Process::kStackCheckDebugInterrupt));
  __ B(NEQ, V0, T0, &overflow);
  __ b(&done_);
  __ ori(V0, ZR, Immediate(Interpreter::kBreakpoint));  // Delay-slot.

  __ Bind(&stay_fast);
  Dispatch(0);

  __ Bind(&overflow);
  Label throw_resume;
  SaveState(&throw_resume);
  __ lw(S3, Address(S0, Process::kProgramOffset));
  __ lw(S3, Address(S3, Program::kStackOverflowErrorOffset));
  DoThrowAfterSaveState(&throw_resume);

  // Intrinsic failure: Just invoke the method.
  __ Bind(&intrinsic_failure_);
  __ la(T9, "InterpreterMethodEntry");
  __ jr(T9);
  __ nop();
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

void InterpreterGeneratorMIPS::Pop(Register reg) {
  __ lw(reg, Address(S2, 0));
  __ addiu(S2, S2, Immediate(1 * kWordSize));
}

void InterpreterGeneratorMIPS::Push(Register reg) {
  __ addiu(S2, S2, Immediate(-1 * kWordSize));
  __ sw(reg, Address(S2, 0));
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
  __ lbu(S3, Address(S1, size));
  if (size > 0) {
    __ addi(S1, S1, Immediate(size));
  }
  __ la(S5, "Interpret_DispatchTable");
  ShiftAddJump(S5, S3, TIMES_WORD_SIZE);
}

void InterpreterGeneratorMIPS::SaveState(Label* resume) {
}

void InterpreterGeneratorMIPS::RestoreState() {
}

void InterpreterGeneratorMIPS::ShiftAddJump(Register reg1,
                                            Register reg2,
                                            int imm) {
  __ sll(T0, reg2, Immediate(imm));
  __ addu(T1, reg1, T0);
  __ lw(T9, Address(T1, 0));
  __ jr(T9);
  __ nop();
}

void InterpreterGeneratorMIPS::PrepareStack() {
  // Reserve 4 words for function arguments and push GP.
  // The stack pointer must always be double-word aligned, so make room for
  // 6 words instead of 5.
  __ addiu(SP, SP, Immediate(-6 * kWordSize));
  __ sw(GP, Address(SP, 5 * kWordSize));
}

void InterpreterGeneratorMIPS::RestoreStack() {
  __ lw(GP, Address(SP, 5 * kWordSize));
  __ addiu(SP, SP, Immediate(6 * kWordSize));
}
}  // namespace dartino
#endif  // defined DARTINO_TARGET_MIPS
