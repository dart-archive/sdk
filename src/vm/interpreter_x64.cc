// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_X64)

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
  explicit InterpreterGenerator(Assembler* assembler) : assembler_(assembler) {}

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

#define V(name)                              \
  assembler()->Bind("", "Intrinsic_" #name); \
  DoIntrinsic##name();
  INTRINSICS_DO(V)
#undef V

  // Define the relative addresses, used in the dispatch table.
#define V(name, branching, format, size, stack_diff, print) \
  assembler()->RelativeDefine("Rel_BC_" #name, "BC_" #name, "LocalInterpret");
  BYTECODES_DO(V)
#undef V
  puts("\n");

  assembler()->SwitchToData();
  assembler()->BindWithPowerOfTwoAlignment("Interpret_DispatchTable", 4);
  assembler()->LocalBind("LocalInterpret_DispatchTable");
#define V(name, branching, format, size, stack_diff, print) \
  assembler()->DefineLong("Rel_BC_" #name);
  BYTECODES_DO(V)
#undef V

  puts("\n");
}

class InterpreterGeneratorX64 : public InterpreterGenerator {
 public:
  explicit InterpreterGeneratorX64(Assembler* assembler)
      : InterpreterGenerator(assembler), spill_size_(-1) {}

  // Registers
  // ---------
  //   r8: stack pointer (C)
  //   r13: bytecode pointer (callee saved)
  //   rsp: stack pointer (Dart)
  //   rbp: frame pointer

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
  Label done_state_saved_;
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

  void StoreByteCodePointer();
  void RestoreByteCodePointer();

  void Return(bool is_return_null);

  void Allocate(bool immutable);

  // This function overwrites the 'object' and 'scratch' registers!
  void AddToRememberedSet(Register object, Register value, Register scratch);

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

  void InvokeNative(bool yield, bool safepoint);

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

GENERATE(, Interpret) {
  InterpreterGeneratorX64 generator(assembler);
  assembler->AlignToPowerOfTwo(4);
  assembler->LocalBind("LocalInterpret");
  generator.Generate();
}

void InterpreterGeneratorX64::GeneratePrologue() {
  // Save callee-saved registers.
  __ pushq(RBP);
  __ pushq(RBX);
  __ pushq(R12);
  __ pushq(R13);
  __ pushq(R14);
  __ pushq(R15);

  // Push the target port address.
  __ pushq(RSI);

  // Push the current process.
  __ pushq(RDI);

  // Create room for Dart stack, when doing native calls.
  __ pushq(Immediate(0));

  // Pad the stack to guarantee the right alignment for calls.
  // Reserved is 6 registers, 1 return address, 1 process, 1 target port and 1
  // Dart stack slot.
  // We reserve two extra slots on the stack for use in DoThrowAfterSaveState.
  spill_size_ = ComputeStackPadding(10 * kWordSize, 2 * kWordSize);
  if (spill_size_ > 0) __ subq(RSP, Immediate(spill_size_));

  // Restore the register state and dispatch to the first bytecode.
  RestoreState();
}

void InterpreterGeneratorX64::GenerateEpilogue() {
  __ Bind(&done_);
  SaveState(&interpreter_entry_);

  // Undo stack padding.
  __ Bind(&done_state_saved_);
  if (spill_size_ > 0) __ addq(RSP, Immediate(spill_size_));

  // Skip Dart stack slot, target port address and process slot.
  __ addq(RSP, Immediate(3 * kWordSize));

  // Restore callee-saved registers.
  __ popq(R15);
  __ popq(R14);
  __ popq(R13);
  __ popq(R12);
  __ popq(RBX);
  __ popq(RBP);
  __ ret();

  // Default entrypoint.
  __ Bind("", "InterpreterEntry");
  __ Bind(&interpreter_entry_);
  Dispatch(0);

  // Handle GC and re-interpret current bytecode.
  __ Bind(&gc_);
  SaveState(&interpreter_entry_);
  LoadProcess(RDI);
  __ call("HandleGC");
  RestoreState();

  // Stack overflow handling (slow case).
  Label stay_fast, overflow, check_debug_interrupt, overflow_resume;
  __ Bind(&check_stack_overflow_0_);
  __ xorq(RAX, RAX);
  __ Bind(&check_stack_overflow_);
  SaveState(&overflow_resume);

  LoadProcess(RDI);
  __ movq(RSI, RAX);
  __ call("HandleStackOverflow");
  RestoreState();
  __ Bind(&overflow_resume);
  __ testq(RAX, RAX);
  ASSERT(Process::kStackCheckContinue == 0);
  __ j(ZERO, &stay_fast);
  __ cmpq(RAX, Immediate(Process::kStackCheckInterrupt));
  __ j(NOT_EQUAL, &check_debug_interrupt);
  __ movq(RAX, Immediate(Interpreter::kInterrupt));
  __ jmp(&done_);
  __ Bind(&check_debug_interrupt);
  __ cmpq(RAX, Immediate(Process::kStackCheckDebugInterrupt));
  __ j(NOT_EQUAL, &overflow);
  __ movq(RAX, Immediate(Interpreter::kBreakpoint));
  __ jmp(&done_);

  __ Bind(&stay_fast);
  Dispatch(0);

  __ Bind(&overflow);
  Label throw_resume;
  SaveState(&throw_resume);
  LoadProgram(RBX);
  __ movq(RBX, Address(RBX, Program::kStackOverflowErrorOffset));
  DoThrowAfterSaveState(&throw_resume);

  // Intrinsic failure: Just invoke the method.
  __ Bind(&intrinsic_failure_);
  __ jmp("LocalInterpreterMethodEntry");
}

void InterpreterGeneratorX64::GenerateMethodEntry() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(3);
  __ Bind("", "InterpreterMethodEntry");
  __ LocalBind("LocalInterpreterMethodEntry");
  __ pushq(RBP);
  __ movq(RBP, RSP);
  __ pushq(Immediate(0));
  __ leaq(R13, Address(RAX, Function::kSize - HeapObject::kTag));
  CheckStackOverflow(0);
  Dispatch(0);
}

void InterpreterGeneratorX64::GenerateBytecodePrologue(const char* name) {
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

void InterpreterGeneratorX64::GenerateDebugAtBytecode() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(4);
  __ Bind("", "DebugAtBytecode");
  // TODO(ajohnsen): Check if the program/process has debug_info set.
  __ popq(RBX);
  LoadProcess(RDI);
  __ movq(RDX, RSP);
  SwitchToCStack();
  __ movq(RSI, R13);
  __ call("HandleAtBytecode");
  SwitchToDartStack();
  __ testq(RAX, RAX);
  __ j(NOT_ZERO, &done_);
  __ pushq(RBX);
  __ ret();
}

void InterpreterGeneratorX64::DoLoadLocal0() {
  LoadLocal(RAX, 0);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal1() {
  LoadLocal(RAX, 1);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal2() {
  LoadLocal(RAX, 2);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal3() {
  LoadLocal(RAX, 3);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal4() {
  LoadLocal(RAX, 4);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal5() {
  LoadLocal(RAX, 5);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLocal() {
  __ movzbq(RAX, Address(R13, 1));
  __ movq(RAX, Address(RSP, RAX, TIMES_WORD_SIZE));
  Push(RAX);
  Dispatch(kLoadLocalLength);
}

void InterpreterGeneratorX64::DoLoadLocalWide() {
  __ movl(RAX, Address(R13, 1));
  __ movq(RAX, Address(RSP, RAX, TIMES_WORD_SIZE));
  Push(RAX);
  Dispatch(kLoadLocalWideLength);
}

void InterpreterGeneratorX64::DoLoadBoxed() {
  __ movzbq(RAX, Address(R13, 1));
  __ movq(RBX, Address(RSP, RAX, TIMES_WORD_SIZE));
  __ movq(RAX, Address(RBX, Boxed::kValueOffset - HeapObject::kTag));
  Push(RAX);
  Dispatch(kLoadBoxedLength);
}

void InterpreterGeneratorX64::DoLoadStatic() {
  __ movl(RAX, Address(R13, 1));
  LoadStaticsArray(RBX);
  __ movq(RAX,
          Address(RBX, RAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag));
  Push(RAX);
  Dispatch(kLoadStaticLength);
}

void InterpreterGeneratorX64::DoLoadStaticInit() {
  __ movl(RAX, Address(R13, 1));
  LoadStaticsArray(RBX);
  __ movq(RAX,
          Address(RBX, RAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag));

  Label done;
  ASSERT(Smi::kTag == 0);
  __ testl(RAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &done);
  __ movq(RBX, Address(RAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movq(RBX, Address(RBX, Class::kInstanceFormatOffset - HeapObject::kTag));

  int type = InstanceFormat::INITIALIZER_TYPE;
  __ andq(RBX, Immediate(InstanceFormat::TypeField::mask()));
  __ cmpq(RBX, Immediate(type << InstanceFormat::TypeField::shift()));
  __ j(NOT_EQUAL, &done);

  // Invoke the initializer function.
  __ movq(RAX, Address(RAX, Initializer::kFunctionOffset - HeapObject::kTag));

  StoreByteCodePointer();
  __ call("LocalInterpreterMethodEntry");
  RestoreByteCodePointer();

  __ Bind(&done);
  Push(RAX);
  Dispatch(kLoadStaticInitLength);
}

void InterpreterGeneratorX64::DoLoadField() {
  __ movzbq(RBX, Address(R13, 1));
  LoadLocal(RAX, 0);
  __ movq(RAX, Address(RAX, RBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  StoreLocal(RAX, 0);
  Dispatch(kLoadFieldLength);
}

void InterpreterGeneratorX64::DoLoadFieldWide() {
  __ movl(RBX, Address(R13, 1));
  LoadLocal(RAX, 0);
  __ movq(RAX, Address(RAX, RBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  StoreLocal(RAX, 0);
  Dispatch(kLoadFieldWideLength);
}

void InterpreterGeneratorX64::DoLoadConst() {
  __ movl(RAX, Address(R13, 1));
  __ movq(RAX, Address(R13, RAX, TIMES_1));
  Push(RAX);
  Dispatch(kLoadConstLength);
}

void InterpreterGeneratorX64::DoStoreLocal() {
  LoadLocal(RBX, 0);
  __ movzbq(RAX, Address(R13, 1));
  __ movq(Address(RSP, RAX, TIMES_WORD_SIZE), RBX);
  Dispatch(2);
}

void InterpreterGeneratorX64::DoStoreBoxed() {
  LoadLocal(RCX, 0);
  __ movzbq(RAX, Address(R13, 1));
  __ movq(RBX, Address(RSP, RAX, TIMES_WORD_SIZE));
  __ movq(Address(RBX, Boxed::kValueOffset - HeapObject::kTag), RCX);

  AddToRememberedSet(RBX, RCX, RAX);

  Dispatch(kStoreBoxedLength);
}

void InterpreterGeneratorX64::DoStoreStatic() {
  LoadLocal(RCX, 0);
  __ movl(RAX, Address(R13, 1));
  LoadStaticsArray(RBX);
  __ movq(Address(RBX, RAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag),
          RCX);

  AddToRememberedSet(RBX, RCX, RAX);

  Dispatch(kStoreStaticLength);
}

void InterpreterGeneratorX64::DoStoreField() {
  __ movzbq(RBX, Address(R13, 1));
  LoadLocal(RCX, 0);
  LoadLocal(RAX, 1);
  __ movq(
      Address(RAX, RBX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      RCX);
  StoreLocal(RCX, 1);
  Drop(1);

  AddToRememberedSet(RAX, RCX, RBX);

  Dispatch(kStoreFieldLength);
}

void InterpreterGeneratorX64::DoStoreFieldWide() {
  __ movl(RBX, Address(R13, 1));
  LoadLocal(RCX, 0);
  LoadLocal(RAX, 1);
  __ movq(
      Address(RAX, RBX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      RCX);
  StoreLocal(RCX, 1);
  Drop(1);

  AddToRememberedSet(RAX, RCX, RBX);

  Dispatch(kStoreFieldWideLength);
}

void InterpreterGeneratorX64::DoLoadLiteralNull() {
  LoadLiteralNull(RAX);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLiteralTrue() {
  LoadLiteralTrue(RAX);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLiteralFalse() {
  LoadLiteralFalse(RAX);
  Push(RAX);
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLiteral0() {
  __ pushq(Immediate(reinterpret_cast<word>(Smi::FromWord(0))));
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLiteral1() {
  __ pushq(Immediate(reinterpret_cast<word>(Smi::FromWord(1))));
  Dispatch(1);
}

void InterpreterGeneratorX64::DoLoadLiteral() {
  __ movzbq(RAX, Address(R13, 1));
  __ shll(RAX, Immediate(Smi::kTagSize));
  ASSERT(Smi::kTag == 0);
  Push(RAX);
  Dispatch(2);
}

void InterpreterGeneratorX64::DoLoadLiteralWide() {
  ASSERT(Smi::kTag == 0);
  __ movl(RAX, Address(R13, 1));
  __ shlq(RAX, Immediate(Smi::kTagSize));
  Push(RAX);
  Dispatch(kLoadLiteralWideLength);
}

void InterpreterGeneratorX64::DoInvokeMethodUnfold() {
  InvokeMethodUnfold(false);
}

void InterpreterGeneratorX64::DoInvokeMethod() {
  InvokeMethod(false);
}

void InterpreterGeneratorX64::DoInvokeNoSuchMethod() {
  // Use the noSuchMethod entry from entry zero of the virtual table.
  LoadProgram(RCX);
  __ movq(RCX, Address(RCX, Program::kDispatchTableOffset));
  __ movq(RCX, Address(RCX, Array::kSize - HeapObject::kTag));

  // Load the function.
  __ movq(RAX,
          Address(RCX, DispatchTableEntry::kTargetOffset - HeapObject::kTag));

  StoreByteCodePointer();
  __ call("LocalInterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movq(RDX, Address(R13, 1));
  ASSERT(Selector::ArityField::shift() == 0);
  __ andq(RDX, Immediate(Selector::ArityField::mask()));

  Drop(RDX);

  StoreLocal(RAX, 0);
  Dispatch(kInvokeNoSuchMethodLength);
}

void InterpreterGeneratorX64::DoInvokeTestNoSuchMethod() {
  LoadLiteralFalse(RAX);
  StoreLocal(RAX, 0);
  Dispatch(kInvokeTestNoSuchMethodLength);
}

void InterpreterGeneratorX64::DoInvokeTestUnfold() {
  InvokeMethodUnfold(true);
}

void InterpreterGeneratorX64::DoInvokeTest() {
  InvokeMethod(true);
}

void InterpreterGeneratorX64::DoInvokeStatic() {
  InvokeStatic();
}

void InterpreterGeneratorX64::DoInvokeFactory() {
  InvokeStatic();
}

void InterpreterGeneratorX64::DoInvokeLeafNative() {
  InvokeNative(false, false);
}

void InterpreterGeneratorX64::DoInvokeNative() {
  InvokeNative(false, true);
}

void InterpreterGeneratorX64::DoInvokeNativeYield() {
  InvokeNative(true, false);
}

void InterpreterGeneratorX64::DoInvokeSelector() {
  Label resume;
  SaveState(&resume);
  LoadProcess(RDI);
  __ call("HandleInvokeSelector");
  RestoreState();
  __ Bind(&resume);

  StoreByteCodePointer();
  __ call("LocalInterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movl(RDX, Address(R13, 1));
  __ negq(RDX);
  __ movq(RDX, Address(RBP, RDX, TIMES_WORD_SIZE, -2 * kWordSize));
  // The selector is smi tagged.
  __ shrq(RDX, Immediate(1));
  ASSERT(Selector::ArityField::shift() == 0);
  __ andq(RDX, Immediate(Selector::ArityField::mask()));

  Drop(RDX);

  StoreLocal(RAX, 0);
  Dispatch(kInvokeSelectorLength);
}

void InterpreterGeneratorX64::InvokeEq(const char* fallback) {
  InvokeCompare(fallback, EQUAL);
}

void InterpreterGeneratorX64::InvokeLt(const char* fallback) {
  InvokeCompare(fallback, LESS);
}

void InterpreterGeneratorX64::InvokeLe(const char* fallback) {
  InvokeCompare(fallback, LESS_EQUAL);
}

void InterpreterGeneratorX64::InvokeGt(const char* fallback) {
  InvokeCompare(fallback, GREATER);
}

void InterpreterGeneratorX64::InvokeGe(const char* fallback) {
  InvokeCompare(fallback, GREATER_EQUAL);
}

void InterpreterGeneratorX64::InvokeAdd(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testl(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testl(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ addq(RAX, RBX);
  __ j(OVERFLOW_, fallback);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeAddLength);
}

void InterpreterGeneratorX64::InvokeSub(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testq(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ subq(RAX, RBX);
  __ j(OVERFLOW_, fallback);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeSubLength);
}

void InterpreterGeneratorX64::InvokeMod(const char* fallback) {
  // TODO(ajohnsen): idiv may yield a negative remainder.
  __ jmp(fallback);
}

void InterpreterGeneratorX64::InvokeMul(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testl(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testl(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag and multiply.
  __ sarq(RAX, Immediate(1));
  __ sarq(RBX, Immediate(1));
  __ imul(RBX);
  __ j(OVERFLOW_, fallback);

  // Re-tag. We need to check for overflow to handle the case
  // where the top two bits are 01 after the multiplication.
  ASSERT(Smi::kTagSize == 1 && Smi::kTag == 0);
  __ addq(RAX, RAX);
  __ j(OVERFLOW_, fallback);

  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeMulLength);
}

void InterpreterGeneratorX64::InvokeTruncDiv(const char* fallback) {
  InvokeDivision(fallback, true);
}

void InterpreterGeneratorX64::InvokeBitNot(const char* fallback) {
  LoadLocal(RAX, 0);
  __ testl(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ notq(RAX);
  __ andq(RAX, Immediate(~Smi::kTagMask));
  StoreLocal(RAX, 0);
  Dispatch(kInvokeBitNotLength);
}

void InterpreterGeneratorX64::InvokeBitAnd(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testq(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ andq(RAX, RBX);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeBitAndLength);
}

void InterpreterGeneratorX64::InvokeBitOr(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testq(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ orq(RAX, RBX);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeBitOrLength);
}

void InterpreterGeneratorX64::InvokeBitXor(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 0);
  __ testq(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ xorq(RAX, RBX);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeBitXorLength);
}

void InterpreterGeneratorX64::InvokeBitShr(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RCX, 0);
  __ testq(RCX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag the smis and do the shift.
  __ sarq(RAX, Immediate(1));
  __ sarq(RCX, Immediate(1));
  __ cmpq(RCX, Immediate(64));
  Label shift;
  __ j(LESS, &shift);
  __ movq(RCX, Immediate(63));
  __ Bind(&shift);
  __ sarq_cl(RAX);

  // Re-tag the resulting smi. No need to check for overflow
  // here, because the top two bits of eax are either 00 or 11
  // because we've shifted eax arithmetically at least one
  // position to the right.
  ASSERT(Smi::kTagSize == 1 && Smi::kTag == 0);
  __ addq(RAX, RAX);

  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeBitShrLength);
}

void InterpreterGeneratorX64::InvokeBitShl(const char* fallback) {
  LoadLocal(RAX, 1);
  __ testq(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RCX, 0);
  __ testq(RCX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag the shift count, but not the value. If the shift
  // count is greater than 31 (or negative), the shift is going
  // to misbehave so we have to guard against that.
  __ sarq(RCX, Immediate(1));
  __ cmpq(RCX, Immediate(64));
  __ j(ABOVE_EQUAL, fallback);

  // Only allow to shift out "sign bits". If we shift
  // out any other bit, it's an overflow.
  __ movq(RBX, RAX);
  __ shlq_cl(RAX);
  __ movq(RDX, RAX);
  __ sarq_cl(RDX);
  __ cmpq(RBX, RDX);
  __ j(NOT_EQUAL, fallback);

  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kInvokeBitShlLength);
}

void InterpreterGeneratorX64::DoPop() {
  Drop(1);
  Dispatch(kPopLength);
}

void InterpreterGeneratorX64::DoDrop() {
  __ movzbq(RAX, Address(R13, 1));
  Drop(RAX);
  Dispatch(kDropLength);
}

void InterpreterGeneratorX64::DoReturn() { Return(false); }

void InterpreterGeneratorX64::DoReturnNull() { Return(true); }

void InterpreterGeneratorX64::DoBranchWide() {
  __ movl(RAX, Address(R13, 1));
  __ addq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchIfTrueWide() {
  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchIfTrueWideLength);

  __ Bind(&branch);
  __ movl(RAX, Address(R13, 1));
  __ addq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchIfFalseWide() {
  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchIfFalseWideLength);

  __ Bind(&branch);
  __ movl(RAX, Address(R13, 1));
  __ addq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBack() {
  CheckStackOverflow(0);
  __ movzbq(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBackIfTrue() {
  CheckStackOverflow(0);

  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchBackIfTrueLength);

  __ Bind(&branch);
  __ movzbq(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBackIfFalse() {
  CheckStackOverflow(0);

  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchBackIfFalseLength);

  __ Bind(&branch);
  __ movzbq(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBackWide() {
  CheckStackOverflow(0);
  __ movl(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBackIfTrueWide() {
  CheckStackOverflow(0);

  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchBackIfTrueWideLength);

  __ Bind(&branch);
  __ movl(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoBranchBackIfFalseWide() {
  CheckStackOverflow(0);

  Label branch;
  Pop(RBX);
  LoadLiteralTrue(RAX);
  __ cmpq(RBX, RAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchBackIfFalseWideLength);

  __ Bind(&branch);
  __ movl(RAX, Address(R13, 1));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoPopAndBranchWide() {
  __ movzbq(RAX, Address(R13, 1));
  __ leaq(RSP, Address(RSP, RAX, TIMES_WORD_SIZE));

  __ movl(RAX, Address(R13, 2));
  __ addq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoPopAndBranchBackWide() {
  CheckStackOverflow(0);

  __ movzbq(RAX, Address(R13, 1));
  __ leaq(RSP, Address(RSP, RAX, TIMES_WORD_SIZE));

  __ movl(RAX, Address(R13, 2));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoAllocate() { Allocate(false); }

void InterpreterGeneratorX64::DoAllocateImmutable() { Allocate(true); }

void InterpreterGeneratorX64::DoAllocateBoxed() {
  LoadLocal(RSI, 0);
  LoadProcess(RDI);
  SwitchToCStack();
  __ call("HandleAllocateBoxed");
  SwitchToDartStack();
  __ movq(RCX, RAX);
  __ andq(RCX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpq(RCX, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);
  StoreLocal(RAX, 0);
  Dispatch(kAllocateBoxedLength);
}

void InterpreterGeneratorX64::DoNegate() {
  Label store;
  LoadLocal(RBX, 0);
  LoadProgram(RCX);
  __ movq(RAX, Address(RCX, Program::kTrueObjectOffset));
  __ cmpq(RBX, RAX);
  __ j(NOT_EQUAL, &store);
  __ movq(RAX, Address(RCX, Program::kFalseObjectOffset));
  __ Bind(&store);
  StoreLocal(RAX, 0);
  Dispatch(kNegateLength);
}

void InterpreterGeneratorX64::DoStackOverflowCheck() {
  __ movl(RAX, Address(R13, 1));
  LoadProcess(RBX);
  __ movq(RBX, Address(RBX, Process::kStackLimitOffset));
  __ negq(RAX);
  __ leaq(RCX, Address(RSP, RAX, TIMES_WORD_SIZE));
  __ cmpq(RCX, RBX);
  __ j(BELOW_EQUAL, &check_stack_overflow_);
  Dispatch(kStackOverflowCheckLength);
}

void InterpreterGeneratorX64::DoThrow() {
  LoadLocal(RBX, 0);
  Label resume;
  SaveState(&resume);
  DoThrowAfterSaveState(&resume);
}

void InterpreterGeneratorX64::DoThrowAfterSaveState(Label* resume) {
  LoadProcess(RDI);
  __ movq(RSI, RBX);
  // Use the stack to store the stack delta initialized to zero.
  __ leaq(RDX, Address(RSP, 0 * kWordSize));
  __ movq(Address(RDX, 0), Immediate(0));
  // Use the stack to store the frame pointer of the target frame.
  __ leaq(RCX, Address(RSP, 1 * kWordSize));
  __ call("HandleThrow");

  RestoreState();
  __ Bind(resume);

  Label unwind;
  __ testq(RAX, RAX);
  __ j(NOT_ZERO, &unwind);
  __ movq(RAX, Immediate(Interpreter::kUncaughtException));
  __ jmp(&done_);

  __ Bind(&unwind);
  __ movq(RBP, Address(R8, 1 * kWordSize));
  __ movq(RCX, Address(R8, 0 * kWordSize));
  __ movq(R13, RAX);
  __ leaq(RSP, Address(RSP, RCX, TIMES_WORD_SIZE));
  StoreLocal(RBX, 0);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoSubroutineCall() {
  __ movl(RAX, Address(R13, 1));
  __ movl(RBX, Address(R13, 5));

  // Push the return delta as a tagged smi.
  ASSERT(Smi::kTag == 0);
  __ shlq(RBX, Immediate(Smi::kTagSize));
  Push(RBX);

  __ addq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoSubroutineReturn() {
  Pop(RAX);
  __ shrq(RAX, Immediate(Smi::kTagSize));
  __ subq(R13, RAX);
  Dispatch(0);
}

void InterpreterGeneratorX64::DoProcessYield() {
  LoadLiteralNull(RBX);
  LoadLocal(RAX, 0);
  __ sarq(RAX, Immediate(1));
  __ addq(R13, Immediate(kProcessYieldLength));
  StoreLocal(RBX, 0);
  __ jmp(&done_);
}

void InterpreterGeneratorX64::DoCoroutineChange() {
  LoadLiteralNull(RAX);

  LoadLocal(RBX, 0);  // Load argument.
  LoadLocal(RSI, 1);  // Load coroutine.

  StoreLocal(RAX, 0);
  StoreLocal(RAX, 1);

  Label resume;
  SaveState(&resume);
  LoadProcess(RDI);
  // RSI already loaded with coroutine.
  __ call("HandleCoroutineChange");
  RestoreState();

  __ Bind(&resume);
  __ Bind("", "InterpreterCoroutineEntry");

  StoreLocal(RBX, 1);
  Drop(1);

  Dispatch(kCoroutineChangeLength);
}

void InterpreterGeneratorX64::DoIdentical() {
  LoadLocal(RAX, 0);
  LoadLocal(RBX, 1);

  // TODO(ager): For now we bail out if we have two doubles or two
  // large integers and let the slow interpreter deal with it. These
  // cases could be dealt with directly here instead.
  Label fast_case;
  Label bail_out;

  // If either is a smi they are not both doubles or large integers.
  __ testq(RAX, Immediate(Smi::kTagMask));
  __ j(ZERO, &fast_case);
  __ testq(RBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &fast_case);

  // If they do not have the same type they are not both double or
  // large integers.
  __ movq(RCX, Address(RAX, HeapObject::kClassOffset - HeapObject::kTag));
  __ movq(RCX, Address(RCX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ movq(RDX, Address(RBX, HeapObject::kClassOffset - HeapObject::kTag));
  __ cmpq(RCX, Address(RDX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &fast_case);

  int double_type = InstanceFormat::DOUBLE_TYPE;
  int large_integer_type = InstanceFormat::LARGE_INTEGER_TYPE;
  int type_field_shift = InstanceFormat::TypeField::shift();

  __ andq(RCX, Immediate(InstanceFormat::TypeField::mask()));
  __ cmpq(RCX, Immediate(double_type << type_field_shift));
  __ j(EQUAL, &bail_out);
  __ cmpq(RCX, Immediate(large_integer_type << type_field_shift));
  __ j(EQUAL, &bail_out);

  __ Bind(&fast_case);
  LoadProgram(RCX);

  Label true_case;
  __ cmpq(RBX, RAX);
  __ j(EQUAL, &true_case);

  __ movq(RAX, Address(RCX, Program::kFalseObjectOffset));
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kIdenticalLength);

  __ Bind(&true_case);
  __ movq(RAX, Address(RCX, Program::kTrueObjectOffset));

  Label done;
  __ Bind(&done);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kIdenticalLength);

  __ Bind(&bail_out);
  LoadProcess(RDI);
  SwitchToCStack();
  __ movq(RSI, RBX);
  __ movq(RDX, RAX);
  __ call("HandleIdentical");
  SwitchToDartStack();
  __ jmp(&done);
}

void InterpreterGeneratorX64::DoIdenticalNonNumeric() {
  LoadLocal(RAX, 0);
  LoadLocal(RBX, 1);
  LoadProgram(RCX);

  Label true_case;
  __ cmpq(RAX, RBX);
  __ j(EQUAL, &true_case);

  __ movq(RAX, Address(RCX, Program::kFalseObjectOffset));
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);

  __ Bind(&true_case);
  __ movq(RAX, Address(RCX, Program::kTrueObjectOffset));
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);
}

void InterpreterGeneratorX64::DoEnterNoSuchMethod() {
  SaveState(&interpreter_entry_);
  LoadProcess(RDI);
  __ call("HandleEnterNoSuchMethod");
  RestoreState();
}

void InterpreterGeneratorX64::DoExitNoSuchMethod() {
  Pop(RAX);  // Result.
  Pop(RBX);  // Selector.
  __ shrq(RBX, Immediate(Smi::kTagSize));

  __ movq(RSP, RBP);
  __ popq(RBP);

  Label done;
  __ movq(RCX, RBX);
  __ andq(RCX, Immediate(Selector::KindField::mask()));
  __ cmpq(RCX, Immediate(Selector::SETTER << Selector::KindField::shift()));
  __ j(NOT_EQUAL, &done);

  // Setter argument is at offset 1, as we still have the return address on the
  // stack.
  LoadLocal(RAX, 1);

  __ Bind(&done);
  __ ret();
}

void InterpreterGeneratorX64::DoMethodEnd() { __ int3(); }

void InterpreterGeneratorX64::DoIntrinsicObjectEquals() {
  // TODO(ajohnsen): Should be enabled again.
  __ int3();
}

void InterpreterGeneratorX64::DoIntrinsicGetField() {
  __ movzbq(RBX, Address(RAX, 2 + Function::kSize - HeapObject::kTag));
  LoadLocal(RAX, 1);
  __ movq(RAX, Address(RAX, RBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  __ ret();
}

void InterpreterGeneratorX64::DoIntrinsicSetField() {
  __ movzbq(RAX, Address(RAX, 3 + Function::kSize - HeapObject::kTag));
  LoadLocal(RBX, 1);
  LoadLocal(RCX, 2);
  __ movq(
      Address(RCX, RAX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      RBX);

  // The value register (RBX) is not overwritten by the write barrier.
  AddToRememberedSet(RCX, RBX, RAX);

  __ movq(RAX, RBX);
  __ ret();
}

void InterpreterGeneratorX64::DoIntrinsicListIndexGet() {
  LoadLocal(RBX, 1);  // Index.
  LoadLocal(RCX, 2);  // List.

  Label failure;
  ASSERT(Smi::kTag == 0);
  __ testl(RBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &intrinsic_failure_);
  __ cmpq(RBX, Immediate(0));
  __ j(LESS, &intrinsic_failure_);

  // Load the backing store (array) from the first instance field of the list.
  __ movq(RCX, Address(RCX, Instance::kSize - HeapObject::kTag));
  __ movq(RDX, Address(RCX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpq(RBX, RDX);
  __ j(GREATER_EQUAL, &intrinsic_failure_);

  // Load from the array and continue.
  ASSERT(Smi::kTagSize == 1);
  __ movq(RAX, Address(RCX, RBX, TIMES_4, Array::kSize - HeapObject::kTag));

  __ ret();
}

void InterpreterGeneratorX64::DoIntrinsicListIndexSet() {
  LoadLocal(RBX, 2);  // Index.
  LoadLocal(RCX, 3);  // List.

  ASSERT(Smi::kTag == 0);
  __ testl(RBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &intrinsic_failure_);
  __ cmpq(RBX, Immediate(0));
  __ j(LESS, &intrinsic_failure_);

  // Load the backing store (array) from the first instance field of the list.
  __ movq(RCX, Address(RCX, Instance::kSize - HeapObject::kTag));
  __ movq(RDX, Address(RCX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpq(RBX, RDX);
  __ j(GREATER_EQUAL, &intrinsic_failure_);

  // Free up EBX, as we need the result (setter value) there.
  __ movq(RAX, RBX);

  // Store to the array and continue.
  ASSERT(Smi::kTagSize == 1);
  LoadLocal(RBX, 1);
  // Index (in RAX) is already smi-taged, so only scale by TIMES_4.
  __ movq(Address(RCX, RAX, TIMES_4, Array::kSize - HeapObject::kTag), RBX);

  // The value register (RBX) is not overwritten by the write barrier.
  AddToRememberedSet(RCX, RBX, RAX);

  __ movq(RAX, RBX);
  __ ret();
}

void InterpreterGeneratorX64::DoIntrinsicListLength() {
  // Load the backing store (array) from the first instance field of the list.
  LoadLocal(RCX, 1);  // List.
  __ movq(RCX, Address(RCX, Instance::kSize - HeapObject::kTag));
  __ movq(RAX, Address(RCX, Array::kLengthOffset - HeapObject::kTag));

  __ ret();
}

void InterpreterGeneratorX64::Push(Register reg) { __ pushq(reg); }

void InterpreterGeneratorX64::Pop(Register reg) { __ popq(reg); }

void InterpreterGeneratorX64::Drop(int n) {
  __ addq(RSP, Immediate(n * kWordSize));
}

void InterpreterGeneratorX64::Drop(Register reg) {
  __ leaq(RSP, Address(RSP, reg, TIMES_WORD_SIZE));
}

void InterpreterGeneratorX64::LoadProcess(Register reg) {
  __ movq(reg, Address(R8, spill_size_ + kWordSize));
}

void InterpreterGeneratorX64::LoadProgram(Register reg) {
  LoadProcess(reg);
  __ movq(reg, Address(reg, Process::kProgramOffset));
}

void InterpreterGeneratorX64::LoadStaticsArray(Register reg) {
  LoadProcess(reg);
  __ movq(reg, Address(reg, Process::kStaticsOffset));
}

void InterpreterGeneratorX64::LoadLiteralNull(Register reg) {
  LoadProgram(reg);
  __ movq(reg, Address(reg, Program::kNullObjectOffset));
}

void InterpreterGeneratorX64::LoadLiteralTrue(Register reg) {
  LoadProgram(reg);
  __ movq(reg, Address(reg, Program::kTrueObjectOffset));
}

void InterpreterGeneratorX64::LoadLiteralFalse(Register reg) {
  LoadProgram(reg);
  __ movq(reg, Address(reg, Program::kFalseObjectOffset));
}

void InterpreterGeneratorX64::SwitchToDartStack() {
  __ movq(R8, RSP);
  __ movq(RSP, Address(R8, spill_size_));
}

void InterpreterGeneratorX64::SwitchToCStack() {
  __ movq(Address(R8, spill_size_), RSP);
  __ movq(RSP, R8);
}

void InterpreterGeneratorX64::StoreByteCodePointer() {
  __ movq(Address(RBP, -kWordSize), R13);
}

void InterpreterGeneratorX64::RestoreByteCodePointer() {
  __ movq(R13, Address(RBP, -kWordSize));
}

void InterpreterGeneratorX64::LoadLocal(Register reg, int index) {
  __ movq(reg, Address(RSP, index * kWordSize));
}

void InterpreterGeneratorX64::StoreLocal(Register reg, int index) {
  __ movq(Address(RSP, index * kWordSize), reg);
}

void InterpreterGeneratorX64::StoreLocal(const Immediate& value, int index) {
  __ movq(Address(RSP, index * kWordSize), value);
}

void InterpreterGeneratorX64::Return(bool is_return_null) {
  // Materialize the result in register RAX.
  if (is_return_null) {
    LoadLiteralNull(RAX);
  } else {
    LoadLocal(RAX, 0);
  }
  __ movq(RSP, RBP);
  __ popq(RBP);
  __ ret();
}

void InterpreterGeneratorX64::Allocate(bool immutable) {
  // Load the class into register rbx.
  __ movl(RAX, Address(R13, 1));
  __ movq(RBX, Address(R13, RAX, TIMES_1));

  // Initialization of 'allocate immutable' argument depends on [immutable].
  __ movq(RDX, Immediate(immutable ? 1 : 0));

  // Loop over all arguments and find out if all of them are immutable (then we
  // can set the immutable bit in this object too).
  Label allocate;
  if (immutable) {
    __ movq(R11, Address(RBX, Class::kInstanceFormatOffset - HeapObject::kTag));
    __ andq(R11, Immediate(InstanceFormat::FixedSizeField::mask()));
    int size_shift = InstanceFormat::FixedSizeField::shift() - kPointerSizeLog2;
    __ shrq(R11, Immediate(size_shift));

    // R11 = SizeOfEntireObject - Instance::kSize
    __ subq(R11, Immediate(Instance::kSize));

    // R10 = StackPointer(RSP) + NumberOfFields*kPointerSize
    __ movq(R10, RSP);
    __ addq(R10, R11);

    Label loop;
    Label break_loop_with_mutable_field;

    // Decrement pointer to point to next field.
    __ Bind(&loop);
    __ subq(R10, Immediate(kPointerSize));

    // Test whether R10 < RSP. If so we're done and it's immutable.
    __ cmpq(R10, RSP);
    __ j(BELOW, &allocate);

    // If Smi, continue the loop.
    __ movq(R11, Address(R10));
    __ testl(R11, Immediate(Smi::kTagMask));
    __ j(ZERO, &loop);

    // Load class of object we want to test immutability of.
    __ movq(RAX, Address(R11, HeapObject::kClassOffset - HeapObject::kTag));

    // Load instance format & handle the three cases:
    //  - never immutable (based on instance format) => not immutable
    //  - always immutable (based on instance format) => immutable
    //  - else (only instances) => check runtime-tracked bit
    uword mask = InstanceFormat::ImmutableField::mask();
    uword always_immutable_mask = InstanceFormat::ImmutableField::encode(
        InstanceFormat::ALWAYS_IMMUTABLE);
    uword never_immutable_mask =
        InstanceFormat::ImmutableField::encode(InstanceFormat::NEVER_IMMUTABLE);

    __ movq(RAX, Address(RAX, Class::kInstanceFormatOffset - HeapObject::kTag));
    __ andq(RAX, Immediate(mask));

    // If this is type never immutable we break the loop.
    __ cmpq(RAX, Immediate(never_immutable_mask));
    __ j(EQUAL, &break_loop_with_mutable_field);

    // If this is type is always immutable we continue the loop.
    __ cmpq(RAX, Immediate(always_immutable_mask));
    __ j(EQUAL, &loop);

    // Else, we must have an Instance and check the runtime-tracked
    // immutable bit.
    uword im_mask = Instance::FlagsImmutabilityField::encode(true);
    __ movq(R11, Address(R11, Instance::kFlagsOffset - HeapObject::kTag));
    __ testq(R11, Immediate(im_mask));
    __ j(NOT_ZERO, &loop);

    __ Bind(&break_loop_with_mutable_field);
    __ movl(RDX, Immediate(0));
    // Fall through.
  }

  // TODO(kasperl): Consider inlining this in the interpreter.
  __ Bind(&allocate);
  LoadProcess(RDI);
  SwitchToCStack();
  __ movq(RSI, RBX);
  // NOTE: The 3rd argument is already present in RDX
  __ call("HandleAllocate");
  SwitchToDartStack();
  __ movq(R11, RAX);
  __ andq(R11, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpq(R11, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);

  __ movq(R11, Address(RBX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ andq(R11, Immediate(InstanceFormat::FixedSizeField::mask()));
  // The fixed size is recorded as the number of pointers. Therefore, the
  // size in bytes is the recorded size multiplied by kPointerSize. Instead
  // of doing the multiplication we shift by kPointerSizeLog2 less.
  ASSERT(InstanceFormat::FixedSizeField::shift() >= kPointerSizeLog2);
  int size_shift = InstanceFormat::FixedSizeField::shift() - kPointerSizeLog2;
  __ shrq(R11, Immediate(size_shift));

  // Compute the address of the first and last instance field.
  __ leaq(R10, Address(RAX, R11, TIMES_1, -1 * kWordSize - HeapObject::kTag));
  __ leaq(R11, Address(RAX, Instance::kSize - HeapObject::kTag));

  Label loop, done;
  __ Bind(&loop);
  __ cmpq(R10, R11);
  __ j(BELOW, &done);
  Pop(RBX);
  // No write barrier, because newly allocated instances are always
  // in new-space, or are already entered into the remembered set.
  __ movq(Address(R10, 0), RBX);
  __ subq(R10, Immediate(1 * kWordSize));
  __ jmp(&loop);

  __ Bind(&done);
  Push(RAX);
  Dispatch(kAllocateLength);
}

void InterpreterGeneratorX64::AddToRememberedSet(Register object,
                                                 Register value,
                                                 Register scratch) {
  Label smi;
  __ testq(value, Immediate(Smi::kTagMask));
  __ j(ZERO, &smi);
  // TODO(erikcorry): Filter out non-new-space values.

  LoadProcess(scratch);
  __ shrq(object, Immediate(GCMetadata::kCardSizeLog2));
  __ addq(object, Address(scratch, Process::kRememberedSetBiasOffset));
  __ movb(Address(object), Immediate(GCMetadata::kNewSpacePointers));

  __ Bind(&smi);
}

void InterpreterGeneratorX64::InvokeMethodUnfold(bool test) {
  // Get the selector from the bytecodes.
  __ movl(RDX, Address(R13, 1));

  if (test) {
    // Get the receiver from the stack.
    LoadLocal(RBX, 0);
  } else {
    // Compute the arity from the selector.
    ASSERT(Selector::ArityField::shift() == 0);
    __ movq(RBX, RDX);
    __ andq(RBX, Immediate(Selector::ArityField::mask()));

    // Get the receiver from the stack.
    __ movq(RBX, Address(RSP, RBX, TIMES_WORD_SIZE));
  }

  // Compute the receiver class.
  Label smi, probe;
  ASSERT(Smi::kTag == 0);
  __ testq(RBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &smi);
  __ movq(RBX, Address(RBX, HeapObject::kClassOffset - HeapObject::kTag));

  // Find the entry in the primary lookup cache.
  Label miss, finish;
  ASSERT(Utils::IsPowerOfTwo(LookupCache::kPrimarySize));
  ASSERT(sizeof(LookupCache::Entry) == 1 << 5);
  __ Bind(&probe);
  __ movq(RAX, RBX);
  __ xorq(RAX, RDX);
  __ andq(RAX, Immediate(LookupCache::kPrimarySize - 1));
  __ shlq(RAX, Immediate(5));
  LoadProcess(RCX);
  __ movq(RCX, Address(RCX, Process::kPrimaryLookupCacheOffset));
  __ addq(RAX, RCX);

  // Validate the primary entry.
  __ cmpq(RBX, Address(RAX, LookupCache::kClassOffset));
  __ j(NOT_EQUAL, &miss);
  __ cmpq(RDX, Address(RAX, LookupCache::kSelectorOffset));
  __ j(NOT_EQUAL, &miss);

  // At this point, we've got our hands on a valid lookup cache entry.
  __ Bind(&finish);
  if (test) {
    __ movq(RAX, Address(RAX, LookupCache::kCodeOffset));
  } else {
    __ movq(RBX, Address(RAX, LookupCache::kCodeOffset));
    __ movq(RAX, Address(RAX, LookupCache::kTargetOffset));

    __ testq(RBX, RBX);

    __ LoadLabel(RCX, "LocalInterpreterMethodEntry");
    __ cmove(RBX, RCX);
  }

  if (test) {
    // Materialize either true or false depending on whether or not
    // we've found a target method.
    Label found;
    LoadProgram(RBX);
    __ testq(RAX, RAX);
    __ j(NOT_ZERO, &found);

    __ movq(RAX, Address(RBX, Program::kFalseObjectOffset));
    StoreLocal(RAX, 0);
    Dispatch(kInvokeTestUnfoldLength);

    __ Bind(&found);
    __ movq(RAX, Address(RBX, Program::kTrueObjectOffset));
    StoreLocal(RAX, 0);
    Dispatch(kInvokeTestUnfoldLength);
  } else {
    StoreByteCodePointer();
    __ call(RBX);
    RestoreByteCodePointer();

    __ movq(RDX, Address(R13, 1));
    ASSERT(Selector::ArityField::shift() == 0);
    __ andq(RDX, Immediate(Selector::ArityField::mask()));

    Drop(RDX);

    StoreLocal(RAX, 0);
    Dispatch(kInvokeMethodUnfoldLength);
  }

  __ Bind(&smi);
  LoadProgram(RBX);
  __ movq(RBX, Address(RBX, Program::kSmiClassOffset));
  __ jmp(&probe);

  // We didn't find a valid entry in primary lookup cache.
  __ Bind(&miss);
  LoadProcess(RDI);
  SwitchToCStack();
  __ movq(RSI, RAX);
  // TODO(ajohnsen): Swap RCX with RDX and RDX with RBX.
  __ movq(RCX, RDX);  // Argument 4
  __ movq(RDX, RBX);  // Argument 3
  __ call("HandleLookupEntry");
  SwitchToDartStack();
  __ jmp(&finish);
}

void InterpreterGeneratorX64::InvokeMethod(bool test) {
  // Get the selector from the bytecodes.
  __ movl(RDX, Address(R13, 1));

  // Fetch the dispatch table from the program.
  LoadProgram(RCX);
  __ movq(RCX, Address(RCX, Program::kDispatchTableOffset));

  if (!test) {
    // Compute the arity from the selector.
    ASSERT(Selector::ArityField::shift() == 0);
    __ movq(RBX, RDX);
    __ andq(RBX, Immediate(Selector::ArityField::mask()));
  }

  // Compute the selector offset (smi tagged) from the selector.
  __ movq(R12, Immediate(Selector::IdField::mask()));
  __ andq(RDX, R12);
  __ shrq(RDX, Immediate(Selector::IdField::shift() - Smi::kTagSize));

  // Get the receiver from the stack.
  if (test) {
    LoadLocal(RBX, 0);
  } else {
    __ movq(RBX, Address(RSP, RBX, TIMES_WORD_SIZE));
  }

  // Compute the receiver class.
  Label smi, dispatch;
  ASSERT(Smi::kTag == 0);
  __ testl(RBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &smi);
  __ movq(RBX, Address(RBX, HeapObject::kClassOffset - HeapObject::kTag));

  // Compute entry index: class id + selector offset.
  int id_offset = Class::kIdOrTransformationTargetOffset - HeapObject::kTag;
  __ Bind(&dispatch);
  __ movq(RBX, Address(RBX, id_offset));
  __ addq(RBX, RDX);

  // Fetch the entry from the table. Because the index is smi tagged
  // we only multiply by four -- not eight -- when indexing.
  ASSERT(Smi::kTagSize == 1);
  __ movq(RCX, Address(RCX, RBX, TIMES_4, Array::kSize - HeapObject::kTag));

  // Validate that the offset stored in the entry matches the offset
  // we used to find it.
  Label invalid;
  __ cmpq(RDX,
          Address(RCX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &invalid);

  Label validated;
  if (test) {
    // Valid entry: The answer is true.
    LoadLiteralTrue(RAX);
    StoreLocal(RAX, 0);
    Dispatch(kInvokeTestLength);
  } else {
    // Load the target from the entry.
    __ Bind(&validated);

    __ movq(
        RAX,
        Address(RCX, DispatchTableEntry::kTargetOffset - HeapObject::kTag));

    StoreByteCodePointer();
    __ call(Address(RCX, DispatchTableEntry::kCodeOffset - HeapObject::kTag));
    RestoreByteCodePointer();

    __ movq(RDX, Address(R13, 1));
    ASSERT(Selector::ArityField::shift() == 0);
    __ andq(RDX, Immediate(Selector::ArityField::mask()));

    Drop(RDX);

    StoreLocal(RAX, 0);
    Dispatch(kInvokeMethodLength);
  }

  __ Bind(&smi);
  LoadProgram(RBX);
  __ movq(RBX, Address(RBX, Program::kSmiClassOffset));
  __ jmp(&dispatch);

  if (test) {
    // Invalid entry: The answer is false.
    __ Bind(&invalid);
    LoadLiteralFalse(RAX);
    StoreLocal(RAX, 0);
    Dispatch(kInvokeTestLength);
  } else {
    // Invalid entry: Use the noSuchMethod entry from entry zero of
    // the virtual table.
    __ Bind(&invalid);
    LoadProgram(RCX);
    __ movq(RCX, Address(RCX, Program::kDispatchTableOffset));
    __ movq(RCX, Address(RCX, Array::kSize - HeapObject::kTag));
    __ jmp(&validated);
  }
}

void InterpreterGeneratorX64::InvokeStatic() {
  __ movl(RAX, Address(R13, 1));
  __ movq(RAX, Address(R13, RAX, TIMES_1));

  StoreByteCodePointer();
  __ call("LocalInterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movl(RDX, Address(R13, 1));
  __ movq(RDX, Address(R13, RDX, TIMES_1));

  // Read the arity from the function. Note that the arity is smi tagged.
  __ movq(RDX, Address(RDX, Function::kArityOffset - HeapObject::kTag));
  __ shrq(RDX, Immediate(Smi::kTagSize));

  Drop(RDX);

  Push(RAX);
  Dispatch(kInvokeStaticLength);
}

void InterpreterGeneratorX64::InvokeCompare(const char* fallback,
                                            Condition condition) {
  LoadLocal(RAX, 0);
  __ testl(RAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(RBX, 1);
  __ testl(RBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  Label true_case;
  __ cmpq(RBX, RAX);
  __ j(condition, &true_case);

  LoadLiteralFalse(RAX);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(5);

  __ Bind(&true_case);
  LoadLiteralTrue(RAX);
  StoreLocal(RAX, 1);
  Drop(1);
  Dispatch(5);
}

void InterpreterGeneratorX64::InvokeDivision(const char* fallback,
                                             bool quotient) {
  // TODO(ager): Implement.
  __ jmp(fallback);
}

void InterpreterGeneratorX64::InvokeNative(bool yield, bool safepoint) {
  __ movzbq(RBX, Address(R13, 1));
  __ movzbq(RCX, Address(R13, 2));

  __ LoadNative(RAX, RCX);

  // Extract address for first argument (note we skip two empty slots).
  __ leaq(RSI, Address(RSP, RBX, TIMES_WORD_SIZE, 2 * kWordSize));
  LoadProcess(RDI);

  Label continue_with_result;

  if (safepoint) {
    SaveState(&continue_with_result);
  } else {
    SwitchToCStack();
  }
  __ call(RAX);
  if (safepoint) {
    RestoreState();
  } else {
    SwitchToDartStack();
  }

  __ Bind(&continue_with_result);
  Label failure;
  __ movq(RCX, RAX);
  __ andq(RCX, Immediate(Failure::kTagMask));
  __ cmpq(RCX, Immediate(Failure::kTag));
  __ j(EQUAL, &failure);

  // Result is now in eax.
  if (yield) {
    ASSERT(!safepoint);

    // If the result of calling the native is null, we don't yield.
    LoadLiteralNull(RCX);
    Label dont_yield;
    __ cmpq(RAX, RCX);
    __ j(EQUAL, &dont_yield);

    // Yield to the target port.
    __ movq(RCX, Address(R8, spill_size_ + 2 * kWordSize));
    __ movq(Address(RCX, 0), RAX);
    __ movq(RAX, Immediate(Interpreter::kTargetYield));

    SaveState(&dont_yield);
    __ jmp(&done_state_saved_);

    __ Bind(&dont_yield);

    LoadLiteralNull(RAX);
  }

  __ movq(RSP, RBP);
  __ popq(RBP);

  __ ret();

  // Failure: Check if it's a request to garbage collect. If not,
  // just continue running the failure block by dispatching to the
  // next bytecode.
  __ Bind(&failure);
  __ movq(RCX, RAX);
  __ andq(RCX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpq(RCX, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);

  // TODO(kasperl): This should be reworked. We shouldn't be calling
  // through the runtime system for something as simple as converting
  // a failure object to the corresponding heap object.
  LoadProcess(RDI);
  SwitchToCStack();
  __ movq(RSI, RAX);
  __ call("HandleObjectFromFailure");
  SwitchToDartStack();

  Push(RAX);
  Dispatch(kInvokeNativeLength);
}

void InterpreterGeneratorX64::CheckStackOverflow(int size) {
  LoadProcess(RBX);
  __ movq(RBX, Address(RBX, Process::kStackLimitOffset));
  __ cmpq(RSP, RBX);
  if (size == 0) {
    __ j(BELOW_EQUAL, &check_stack_overflow_0_);
  } else {
    Label done;
    __ j(BELOW, &done);
    __ movq(RAX, Immediate(size));
    __ jmp(&check_stack_overflow_);
    __ Bind(&done);
  }
}

void InterpreterGeneratorX64::Dispatch(int size) {
  __ movzbq(RBX, Address(R13, size));
  if (size > 0) {
    __ addq(R13, Immediate(size));
  }
  __ jmp("LocalInterpret_DispatchTable", RBX, TIMES_WORD_SIZE, RAX);
}

void InterpreterGeneratorX64::SaveState(Label* resume) {
  // Save the bytecode pointer at the bcp slot.
  StoreByteCodePointer();

  // Push resume address.
  __ movq(RCX, resume);
  Push(RCX);

  // Push frame pointer.
  Push(RBP);

  // Update top in the stack. Ugh. Complicated.
  // First load the current coroutine's stack.
  LoadProcess(RCX);
  __ movq(RCX, Address(RCX, Process::kCoroutineOffset));
  __ movq(RCX, Address(RCX, Coroutine::kStackOffset - HeapObject::kTag));
  // Calculate the index of the stack.
  __ subq(RSP, RCX);
  __ subq(RSP, Immediate(Stack::kSize - HeapObject::kTag));
  // We now have the distance to the top pointer in bytes. We need to
  // store the index, measured in words, as a Smi-tagged integer.  To do so,
  // shift by two.
  __ shrq(RSP, Immediate(2));
  // And finally store it in the stack object.
  __ movq(Address(RCX, Stack::kTopOffset - HeapObject::kTag), RSP);

  // Restore the C stack in RSP.
  __ movq(RSP, R8);
}

void InterpreterGeneratorX64::RestoreState() {
  // Store the C stack in R8.
  __ movq(R8, RSP);

  // First load the current coroutine's stack.
  // Load the Dart stack pointer into RSP.
  LoadProcess(RSP);
  __ movq(RSP, Address(RSP, Process::kCoroutineOffset));
  __ movq(RSP, Address(RSP, Coroutine::kStackOffset - HeapObject::kTag));
  // Load the top index.
  __ movq(RCX, Address(RSP, Stack::kTopOffset - HeapObject::kTag));
  // Load the address of the top position. Note top is a Smi-tagged count of
  // pointers, so we only need to multiply with 4 to get the offset in bytes.
  __ leaq(RSP, Address(RSP, RCX, TIMES_4, Stack::kSize - HeapObject::kTag));

  // Read frame pointer.
  __ popq(RBP);

  // Set the bcp from the stack.
  RestoreByteCodePointer();

  __ ret();
}

}  // namespace dartino

#endif  // defined DARTINO_TARGET_X64
