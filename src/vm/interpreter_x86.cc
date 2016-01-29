// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_IA32)

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
  assembler()->SwitchToText(); \
  assembler()->AlignToPowerOfTwo(4);         \
  assembler()->Bind("", "Intrinsic_" #name); \
  DoIntrinsic##name();
  INTRINSICS_DO(V)
#undef V

  assembler()->SwitchToData();
  assembler()->BindWithPowerOfTwoAlignment("Interpret_DispatchTable", 4);
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
  //   edi: process pointer
  //   esi: bytecode pointer
  //   esp: stack pointer (Dart)
  //   ebp: frame pointer
  //

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

  void LoadProgram(Register reg);
  void LoadStaticsArray(Register reg);
  void LoadLiteralNull(Register reg);
  void LoadLiteralTrue(Register reg);
  void LoadLiteralFalse(Register reg);

  void LoadNativeStack(Register reg);
  void StoreNativeStack(Register reg);

  void SwitchToDartStack();
  void SwitchToCStack(Register scratch);

  void StoreByteCodePointer();
  void RestoreByteCodePointer();

  void Return(bool is_return_null);

  void Allocate(bool immutable);

  // This function
  //   * changes the first three stack slots
  //   * changes caller-saved registers
  void AddToRememberedSetSlow(Register object, Register value,
                              Register scratch);

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

GENERATE(, Interpret) {
  InterpreterGeneratorX86 generator(assembler);
  generator.Generate();
}

void InterpreterGeneratorX86::GeneratePrologue() {
  __ pushl(EBP);
  __ pushl(EBX);
  __ pushl(EDI);
  __ pushl(ESI);

  // Store the current process.
  __ movl(EDI, Address(ESP, (4 + 1) * kWordSize));

  // Create room for Dart stack, when doing native calls.
  __ pushl(Immediate(0));

  // Pad the stack to guarantee the right alignment for calls.
  // Reserved is 4 registers, 1 return address and 1 Dart stack slot.
  spill_size_ = ComputeStackPadding(6 * kWordSize, 6 * kWordSize);
  if (spill_size_ > 0) __ subl(ESP, Immediate(spill_size_));

  // Restore the register state and dispatch to the first bytecode.
  RestoreState();
}

void InterpreterGeneratorX86::GenerateEpilogue() {
  // Done. Start by saving the register state.
  __ Bind(&done_);
  SaveState(&interpreter_entry_);

  // Undo stack padding.
  __ Bind(&done_state_saved_);
  if (spill_size_ > 0) __ addl(ESP, Immediate(spill_size_));

  // Skip Dart stack slot.
  __ addl(ESP, Immediate(1 * kWordSize));

  // Restore callee-saved registers.
  __ popl(ESI);
  __ popl(EDI);
  __ popl(EBX);
  __ popl(EBP);
  __ ret();

  // Default entrypoint.
  __ Bind("", "InterpreterEntry");
  __ Bind(&interpreter_entry_);
  Dispatch(0);

  // Handle GC and re-interpret current bytecode.
  __ Bind(&gc_);
  SaveState(&interpreter_entry_);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleGC");
  RestoreState();

  // Stack overflow handling (slow case).
  Label stay_fast, overflow, check_debug_interrupt, overflow_resume;
  __ Bind(&check_stack_overflow_0_);
  __ xorl(EAX, EAX);
  __ Bind(&check_stack_overflow_);
  SaveState(&overflow_resume);

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ call("HandleStackOverflow");
  RestoreState();
  __ Bind(&overflow_resume);
  __ testl(EAX, EAX);
  ASSERT(Process::kStackCheckContinue == 0);
  __ j(ZERO, &stay_fast);
  __ cmpl(EAX, Immediate(Process::kStackCheckInterrupt));
  __ j(NOT_EQUAL, &check_debug_interrupt);
  __ movl(EAX, Immediate(Interpreter::kInterrupt));
  __ jmp(&done_);
  __ Bind(&check_debug_interrupt);
  __ cmpl(EAX, Immediate(Process::kStackCheckDebugInterrupt));
  __ j(NOT_EQUAL, &overflow);
  __ movl(EAX, Immediate(Interpreter::kBreakPoint));
  __ jmp(&done_);

  __ Bind(&stay_fast);
  Dispatch(0);

  __ Bind(&overflow);
  Label throw_resume;
  SaveState(&throw_resume);
  LoadProgram(EBX);
  __ movl(EBX, Address(EBX, Program::kStackOverflowErrorOffset));
  DoThrowAfterSaveState(&throw_resume);

  // Intrinsic failure: Just invoke the method.
  __ Bind(&intrinsic_failure_);
  __ jmp("InterpreterMethodEntry");
}

void InterpreterGeneratorX86::GenerateMethodEntry() {
  __ SwitchToText();
  __ AlignToPowerOfTwo(3);
  __ Bind("", "InterpreterMethodEntry");
  __ pushl(EBP);
  __ movl(EBP, ESP);
  __ pushl(Immediate(0));
  __ leal(ESI, Address(EAX, Function::kSize - HeapObject::kTag));
  CheckStackOverflow(0);
  Dispatch(0);
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
  // TODO(ajohnsen): Check if the process has debug_info set.
  __ popl(EBX);
  __ movl(EDX, ESP);
  SwitchToCStack(EAX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), ESI);
  __ movl(Address(ESP, 2 * kWordSize), EDX);
  __ call("HandleAtBytecode");
  SwitchToDartStack();
  __ testl(EAX, EAX);
  __ j(NOT_ZERO, &done_);
  __ pushl(EBX);
  __ ret();
}

void InterpreterGeneratorX86::DoLoadLocal0() {
  LoadLocal(EAX, 0);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal1() {
  LoadLocal(EAX, 1);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal2() {
  LoadLocal(EAX, 2);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal3() {
  LoadLocal(EAX, 3);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal4() {
  LoadLocal(EAX, 4);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal5() {
  LoadLocal(EAX, 5);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLocal() {
  __ movzbl(EAX, Address(ESI, 1));
  __ movl(EAX, Address(ESP, EAX, TIMES_WORD_SIZE));
  Push(EAX);
  Dispatch(kLoadLocalLength);
}

void InterpreterGeneratorX86::DoLoadLocalWide() {
  __ movl(EAX, Address(ESI, 1));
  __ movl(EAX, Address(ESP, EAX, TIMES_WORD_SIZE));
  Push(EAX);
  Dispatch(kLoadLocalWideLength);
}

void InterpreterGeneratorX86::DoLoadBoxed() {
  __ movzbl(EAX, Address(ESI, 1));
  __ movl(EBX, Address(ESP, EAX, TIMES_WORD_SIZE));
  __ movl(EAX, Address(EBX, Boxed::kValueOffset - HeapObject::kTag));
  Push(EAX);
  Dispatch(kLoadBoxedLength);
}

void InterpreterGeneratorX86::DoLoadStatic() {
  __ movl(EAX, Address(ESI, 1));
  LoadStaticsArray(EBX);
  __ movl(EAX,
          Address(EBX, EAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag));
  Push(EAX);
  Dispatch(kLoadStaticLength);
}

void InterpreterGeneratorX86::DoLoadStaticInit() {
  __ movl(EAX, Address(ESI, 1));
  LoadStaticsArray(EBX);
  __ movl(EAX,
          Address(EBX, EAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag));

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

  // Invoke the initializer function.
  __ movl(EAX, Address(EAX, Initializer::kFunctionOffset - HeapObject::kTag));

  StoreByteCodePointer();
  __ call("InterpreterMethodEntry");
  RestoreByteCodePointer();

  __ Bind(&done);
  Push(EAX);
  Dispatch(kLoadStaticInitLength);
}

void InterpreterGeneratorX86::DoLoadField() {
  __ movzbl(EBX, Address(ESI, 1));
  LoadLocal(EAX, 0);
  __ movl(EAX, Address(EAX, EBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  StoreLocal(EAX, 0);
  Dispatch(kLoadFieldLength);
}

void InterpreterGeneratorX86::DoLoadFieldWide() {
  __ movl(EBX, Address(ESI, 1));
  LoadLocal(EAX, 0);
  __ movl(EAX, Address(EAX, EBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  StoreLocal(EAX, 0);
  Dispatch(kLoadFieldWideLength);
}

void InterpreterGeneratorX86::DoLoadConst() {
  __ movl(EAX, Address(ESI, 1));
  __ movl(EAX, Address(ESI, EAX, TIMES_1));
  Push(EAX);
  Dispatch(kLoadConstLength);
}

void InterpreterGeneratorX86::DoStoreLocal() {
  LoadLocal(EBX, 0);
  __ movzbl(EAX, Address(ESI, 1));
  __ movl(Address(ESP, EAX, TIMES_WORD_SIZE), EBX);
  Dispatch(2);
}

void InterpreterGeneratorX86::DoStoreBoxed() {
  LoadLocal(ECX, 0);
  __ movzbl(EAX, Address(ESI, 1));
  __ movl(EBX, Address(ESP, EAX, TIMES_WORD_SIZE));
  __ movl(Address(EBX, Boxed::kValueOffset - HeapObject::kTag), ECX);

  AddToRememberedSetSlow(EBX, ECX, EAX);

  Dispatch(kStoreBoxedLength);
}

void InterpreterGeneratorX86::DoStoreStatic() {
  LoadLocal(ECX, 0);
  __ movl(EAX, Address(ESI, 1));
  LoadStaticsArray(EBX);
  __ movl(Address(EBX, EAX, TIMES_WORD_SIZE, Array::kSize - HeapObject::kTag),
          ECX);

  AddToRememberedSetSlow(EBX, ECX, EAX);

  Dispatch(kStoreStaticLength);
}

void InterpreterGeneratorX86::DoStoreField() {
  __ movzbl(EBX, Address(ESI, 1));
  LoadLocal(ECX, 0);
  LoadLocal(EAX, 1);
  __ movl(
      Address(EAX, EBX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      ECX);
  StoreLocal(ECX, 1);
  Drop(1);

  AddToRememberedSetSlow(EAX, ECX, EBX);

  Dispatch(kStoreFieldLength);
}

void InterpreterGeneratorX86::DoStoreFieldWide() {
  __ movl(EBX, Address(ESI, 1));
  LoadLocal(ECX, 0);
  LoadLocal(EAX, 1);
  __ movl(
      Address(EAX, EBX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      ECX);
  StoreLocal(ECX, 1);
  Drop(1);

  AddToRememberedSetSlow(EAX, ECX, EBX);

  Dispatch(kStoreFieldWideLength);
}

void InterpreterGeneratorX86::DoLoadLiteralNull() {
  LoadLiteralNull(EAX);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLiteralTrue() {
  LoadLiteralTrue(EAX);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLiteralFalse() {
  LoadLiteralFalse(EAX);
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLiteral0() {
  __ movl(EAX, Immediate(reinterpret_cast<int32>(Smi::FromWord(0))));
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLiteral1() {
  __ movl(EAX, Immediate(reinterpret_cast<int32>(Smi::FromWord(1))));
  Push(EAX);
  Dispatch(1);
}

void InterpreterGeneratorX86::DoLoadLiteral() {
  __ movzbl(EAX, Address(ESI, 1));
  __ shll(EAX, Immediate(Smi::kTagSize));
  ASSERT(Smi::kTag == 0);
  Push(EAX);
  Dispatch(2);
}

void InterpreterGeneratorX86::DoLoadLiteralWide() {
  ASSERT(Smi::kTag == 0);
  __ movl(EAX, Address(ESI, 1));
  __ shll(EAX, Immediate(Smi::kTagSize));
  Push(EAX);
  Dispatch(kLoadLiteralWideLength);
}

void InterpreterGeneratorX86::DoInvokeMethodUnfold() {
  InvokeMethodUnfold(false);
}

void InterpreterGeneratorX86::DoInvokeMethod() {
  InvokeMethod(false);
}

void InterpreterGeneratorX86::DoInvokeNoSuchMethod() {
  // Use the noSuchMethod entry from entry zero of the virtual table.
  LoadProgram(ECX);
  __ movl(ECX, Address(ECX, Program::kDispatchTableOffset));
  __ movl(ECX, Address(ECX, Array::kSize - HeapObject::kTag));

  // Load the function.
  __ movl(EAX,
          Address(ECX, DispatchTableEntry::kTargetOffset - HeapObject::kTag));

  StoreByteCodePointer();
  __ call("InterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movl(EDX, Address(ESI, 1));
  ASSERT(Selector::ArityField::shift() == 0);
  __ andl(EDX, Immediate(Selector::ArityField::mask()));

  Drop(EDX);

  StoreLocal(EAX, 0);
  Dispatch(kInvokeNoSuchMethodLength);
}

void InterpreterGeneratorX86::DoInvokeTestNoSuchMethod() {
  LoadLiteralFalse(EAX);
  StoreLocal(EAX, 0);
  Dispatch(kInvokeTestNoSuchMethodLength);
}

void InterpreterGeneratorX86::DoInvokeTestUnfold() {
  InvokeMethodUnfold(true);
}

void InterpreterGeneratorX86::DoInvokeTest() {
  InvokeMethod(true);
}

void InterpreterGeneratorX86::DoInvokeStatic() {
  InvokeStatic();
}

void InterpreterGeneratorX86::DoInvokeFactory() {
  InvokeStatic();
}

void InterpreterGeneratorX86::DoInvokeNative() {
  InvokeNative(false);
}

void InterpreterGeneratorX86::DoInvokeNativeYield() {
  InvokeNative(true);
}

void InterpreterGeneratorX86::DoInvokeSelector() {
  Label resume;
  SaveState(&resume);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleInvokeSelector");
  RestoreState();
  __ Bind(&resume);

  StoreByteCodePointer();
  __ call("InterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movl(EDX, Address(ESI, 1));
  __ negl(EDX);
  __ movl(EDX, Address(EBP, EDX, TIMES_WORD_SIZE, -2 * kWordSize));
  // The selector is smi tagged.
  __ shrl(EDX, Immediate(1));
  ASSERT(Selector::ArityField::shift() == 0);
  __ andl(EDX, Immediate(Selector::ArityField::mask()));

  Drop(EDX);

  StoreLocal(EAX, 0);
  Dispatch(kInvokeSelectorLength);
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
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ addl(EAX, EBX);
  __ j(OVERFLOW_, fallback);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeAddLength);
}

void InterpreterGeneratorX86::InvokeSub(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ subl(EAX, EBX);
  __ j(OVERFLOW_, fallback);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeSubLength);
}

void InterpreterGeneratorX86::InvokeMod(const char* fallback) {
  // TODO(ajohnsen): idiv may yield a negative remainder.
  __ jmp(fallback);
}

void InterpreterGeneratorX86::InvokeMul(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag and multiply.
  __ sarl(EAX, Immediate(1));
  __ sarl(EBX, Immediate(1));
  __ imul(EBX);
  __ j(OVERFLOW_, fallback);

  // Re-tag. We need to check for overflow to handle the case
  // where the top two bits are 01 after the multiplication.
  ASSERT(Smi::kTagSize == 1 && Smi::kTag == 0);
  __ addl(EAX, EAX);
  __ j(OVERFLOW_, fallback);

  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeMulLength);
}

void InterpreterGeneratorX86::InvokeTruncDiv(const char* fallback) {
  InvokeDivision(fallback, true);
}

void InterpreterGeneratorX86::InvokeBitNot(const char* fallback) {
  LoadLocal(EAX, 0);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ notl(EAX);
  __ andl(EAX, Immediate(~Smi::kTagMask));
  StoreLocal(EAX, 0);
  Dispatch(kInvokeBitNotLength);
}

void InterpreterGeneratorX86::InvokeBitAnd(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ andl(EAX, EBX);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeBitAndLength);
}

void InterpreterGeneratorX86::InvokeBitOr(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ orl(EAX, EBX);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeBitAndLength);
}

void InterpreterGeneratorX86::InvokeBitXor(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  __ xorl(EAX, EBX);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeBitAndLength);
}

void InterpreterGeneratorX86::InvokeBitShr(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(ECX, 0);
  __ testl(ECX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag the smis and do the shift.
  __ sarl(EAX, Immediate(1));
  __ sarl(ECX, Immediate(1));
  __ cmpl(ECX, Immediate(32));
  Label shift;
  __ j(LESS, &shift);
  __ movl(ECX, Immediate(31));
  __ Bind(&shift);
  __ sarl_cl(EAX);

  // Re-tag the resulting smi. No need to check for overflow
  // here, because the top two bits of eax are either 00 or 11
  // because we've shifted eax arithmetically at least one
  // position to the right.
  ASSERT(Smi::kTagSize == 1 && Smi::kTag == 0);
  __ addl(EAX, EAX);

  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeBitAndLength);
}

void InterpreterGeneratorX86::InvokeBitShl(const char* fallback) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(ECX, 0);
  __ testl(ECX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Untag the shift count, but not the value. If the shift
  // count is greater than 31 (or negative), the shift is going
  // to misbehave so we have to guard against that.
  __ sarl(ECX, Immediate(1));
  __ cmpl(ECX, Immediate(32));
  __ j(ABOVE_EQUAL, fallback);

  // Only allow to shift out "sign bits". If we shift
  // out any other bit, it's an overflow.
  __ movl(EBX, EAX);
  __ shll_cl(EAX);
  __ movl(EDX, EAX);
  __ sarl_cl(EDX);
  __ cmpl(EBX, EDX);
  __ j(NOT_EQUAL, fallback);

  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kInvokeBitShlLength);
}

void InterpreterGeneratorX86::DoPop() {
  Drop(1);
  Dispatch(kPopLength);
}

void InterpreterGeneratorX86::DoDrop() {
  __ movzbl(EAX, Address(ESI, 1));
  Drop(EAX);
  Dispatch(kDropLength);
}

void InterpreterGeneratorX86::DoReturn() { Return(false); }

void InterpreterGeneratorX86::DoReturnNull() { Return(true); }

void InterpreterGeneratorX86::DoBranchWide() {
  __ movl(EAX, Address(ESI, 1));
  __ addl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchIfTrueWide() {
  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchIfTrueWideLength);

  __ Bind(&branch);
  __ movl(EAX, Address(ESI, 1));
  __ addl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchIfFalseWide() {
  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchIfFalseWideLength);

  __ Bind(&branch);
  __ movl(EAX, Address(ESI, 1));
  __ addl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBack() {
  CheckStackOverflow(0);
  __ movzbl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBackIfTrue() {
  CheckStackOverflow(0);

  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchBackIfTrueLength);

  __ Bind(&branch);
  __ movzbl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBackIfFalse() {
  CheckStackOverflow(0);

  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchBackIfFalseLength);

  __ Bind(&branch);
  __ movzbl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBackWide() {
  CheckStackOverflow(0);
  __ movl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBackIfTrueWide() {
  CheckStackOverflow(0);

  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(EQUAL, &branch);
  Dispatch(kBranchBackIfTrueWideLength);

  __ Bind(&branch);
  __ movl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoBranchBackIfFalseWide() {
  CheckStackOverflow(0);

  Label branch;
  Pop(EBX);
  LoadLiteralTrue(EAX);
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &branch);
  Dispatch(kBranchBackIfFalseWideLength);

  __ Bind(&branch);
  __ movl(EAX, Address(ESI, 1));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoPopAndBranchWide() {
  __ movzbl(EAX, Address(ESI, 1));
  __ leal(ESP, Address(ESP, EAX, TIMES_WORD_SIZE));

  __ movl(EAX, Address(ESI, 2));
  __ addl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoPopAndBranchBackWide() {
  CheckStackOverflow(0);

  __ movzbl(EAX, Address(ESI, 1));
  __ leal(ESP, Address(ESP, EAX, TIMES_WORD_SIZE));

  __ movl(EAX, Address(ESI, 2));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoAllocate() { Allocate(false); }

void InterpreterGeneratorX86::DoAllocateImmutable() { Allocate(true); }

void InterpreterGeneratorX86::DoAllocateBoxed() {
  LoadLocal(EBX, 0);
  SwitchToCStack(EAX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  __ call("HandleAllocateBoxed");
  SwitchToDartStack();
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);
  StoreLocal(EAX, 0);
  Dispatch(kAllocateBoxedLength);
}

void InterpreterGeneratorX86::DoNegate() {
  Label store;
  LoadLocal(EBX, 0);
  LoadProgram(ECX);
  __ movl(EAX, Address(ECX, Program::kTrueObjectOffset));
  __ cmpl(EBX, EAX);
  __ j(NOT_EQUAL, &store);
  __ movl(EAX, Address(ECX, Program::kFalseObjectOffset));
  __ Bind(&store);
  StoreLocal(EAX, 0);
  Dispatch(kNegateLength);
}

void InterpreterGeneratorX86::DoStackOverflowCheck() {
  __ movl(EAX, Address(ESI, 1));
  __ movl(EBX, Address(EDI, Process::kStackLimitOffset));
  __ negl(EAX);
  __ leal(ECX, Address(ESP, EAX, TIMES_WORD_SIZE));
  __ cmpl(ECX, EBX);
  __ j(BELOW_EQUAL, &check_stack_overflow_);
  Dispatch(kStackOverflowCheckLength);
}

void InterpreterGeneratorX86::DoThrow() {
  LoadLocal(EBX, 0);
  Label resume;
  SaveState(&resume);
  DoThrowAfterSaveState(&resume);
}

void InterpreterGeneratorX86::DoThrowAfterSaveState(Label* resume) {
  // Use the stack to store the stack delta initialized to zero.
  __ leal(EAX, Address(ESP, 4 * kWordSize));
  __ movl(Address(EAX, 0), Immediate(0));
  // Use the stack to store the frame pointer of the target frame.
  __ leal(ECX, Address(ESP, 5 * kWordSize));

  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  __ movl(Address(ESP, 2 * kWordSize), EAX);
  __ movl(Address(ESP, 3 * kWordSize), ECX);
  __ call("HandleThrow");

  RestoreState();
  __ Bind(resume);

  Label unwind;
  __ testl(EAX, EAX);
  __ j(NOT_ZERO, &unwind);
  __ movl(EAX, Immediate(Interpreter::kUncaughtException));
  __ jmp(&done_);

  __ Bind(&unwind);
  LoadNativeStack(ECX);
  __ movl(EBP, Address(ECX, 5 * kWordSize));
  __ movl(ECX, Address(ECX, 4 * kWordSize));
  __ movl(ESI, EAX);
  __ leal(ESP, Address(ESP, ECX, TIMES_WORD_SIZE));
  StoreLocal(EBX, 0);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoSubroutineCall() {
  __ movl(EAX, Address(ESI, 1));
  __ movl(EBX, Address(ESI, 5));

  // Push the return delta as a tagged smi.
  ASSERT(Smi::kTag == 0);
  __ shll(EBX, Immediate(Smi::kTagSize));
  Push(EBX);

  __ addl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoSubroutineReturn() {
  Pop(EAX);
  __ shrl(EAX, Immediate(Smi::kTagSize));
  __ subl(ESI, EAX);
  Dispatch(0);
}

void InterpreterGeneratorX86::DoProcessYield() {
  LoadLiteralNull(EBX);
  LoadLocal(EAX, 0);
  __ sarl(EAX, Immediate(1));
  __ addl(ESI, Immediate(kProcessYieldLength));
  StoreLocal(EBX, 0);
  __ jmp(&done_);
}

void InterpreterGeneratorX86::DoCoroutineChange() {
  LoadLiteralNull(EAX);

  LoadLocal(EBX, 0);  // Load argument.
  LoadLocal(EDX, 1);  // Load coroutine.

  StoreLocal(EAX, 0);
  StoreLocal(EAX, 1);

  Label resume;
  SaveState(&resume);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EDX);
  __ call("HandleCoroutineChange");
  RestoreState();

  __ Bind(&resume);
  __ Bind("", "InterpreterCoroutineEntry");

  StoreLocal(EBX, 1);
  Drop(1);

  Dispatch(kCoroutineChangeLength);
}

void InterpreterGeneratorX86::DoIdentical() {
  LoadLocal(EAX, 0);
  LoadLocal(EBX, 1);

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
  LoadProgram(ECX);

  Label true_case;
  __ cmpl(EBX, EAX);
  __ j(EQUAL, &true_case);

  __ movl(EAX, Address(ECX, Program::kFalseObjectOffset));
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kIdenticalLength);

  __ Bind(&true_case);
  __ movl(EAX, Address(ECX, Program::kTrueObjectOffset));

  Label done;
  __ Bind(&done);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kIdenticalLength);

  __ Bind(&bail_out);
  SwitchToCStack(ECX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  __ movl(Address(ESP, 2 * kWordSize), EAX);
  __ call("HandleIdentical");
  SwitchToDartStack();
  __ jmp(&done);
}

void InterpreterGeneratorX86::DoIdenticalNonNumeric() {
  LoadLocal(EAX, 0);
  LoadLocal(EBX, 1);
  LoadProgram(ECX);

  Label true_case;
  __ cmpl(EAX, EBX);
  __ j(EQUAL, &true_case);

  __ movl(EAX, Address(ECX, Program::kFalseObjectOffset));
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);

  __ Bind(&true_case);
  __ movl(EAX, Address(ECX, Program::kTrueObjectOffset));
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(kIdenticalNonNumericLength);
}

void InterpreterGeneratorX86::DoEnterNoSuchMethod() {
  SaveState(&interpreter_entry_);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ call("HandleEnterNoSuchMethod");
  RestoreState();
}

void InterpreterGeneratorX86::DoExitNoSuchMethod() {
  Pop(EAX);  // Result.
  Pop(EBX);  // Selector.
  __ shrl(EBX, Immediate(Smi::kTagSize));

  __ movl(ESP, EBP);
  __ popl(EBP);

  Label done;
  __ movl(ECX, EBX);
  __ andl(ECX, Immediate(Selector::KindField::mask()));
  __ cmpl(ECX, Immediate(Selector::SETTER << Selector::KindField::shift()));
  __ j(NOT_EQUAL, &done);

  // Setter argument is at offset 1, as we still have the return address on the
  // stack.
  LoadLocal(EAX, 1);

  __ Bind(&done);
  __ ret();
}

void InterpreterGeneratorX86::DoMethodEnd() { __ int3(); }

void InterpreterGeneratorX86::DoIntrinsicObjectEquals() {
  // TODO(ajohnsen): Should be enabled again.
  __ int3();
}

void InterpreterGeneratorX86::DoIntrinsicGetField() {
  __ movzbl(EBX, Address(EAX, 2 + Function::kSize - HeapObject::kTag));
  LoadLocal(EAX, 1);
  __ movl(EAX, Address(EAX, EBX, TIMES_WORD_SIZE,
                       Instance::kSize - HeapObject::kTag));
  __ ret();
}

void InterpreterGeneratorX86::DoIntrinsicSetField() {
  __ movzbl(EAX, Address(EAX, 3 + Function::kSize - HeapObject::kTag));
  LoadLocal(EBX, 1);
  LoadLocal(ECX, 2);
  __ movl(
      Address(ECX, EAX, TIMES_WORD_SIZE, Instance::kSize - HeapObject::kTag),
      EBX);

  // We have put the result in EBX to be sure it's kept by the preserved by the
  // store-buffer call.
  AddToRememberedSetSlow(ECX, EBX, EAX);

  __ movl(EAX, EBX);
  __ ret();
}

void InterpreterGeneratorX86::DoIntrinsicListIndexGet() {
  LoadLocal(EBX, 1);  // Index.
  LoadLocal(ECX, 2);  // List.

  Label failure;
  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &intrinsic_failure_);
  __ cmpl(EBX, Immediate(0));
  __ j(LESS, &intrinsic_failure_);

  // Load the backing store (array) from the first instance field of the list.
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EDX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpl(EBX, EDX);
  __ j(GREATER_EQUAL, &intrinsic_failure_);

  // Load from the array and continue.
  ASSERT(Smi::kTagSize == 1);
  __ movl(EAX, Address(ECX, EBX, TIMES_2, Array::kSize - HeapObject::kTag));

  __ ret();
}

void InterpreterGeneratorX86::DoIntrinsicListIndexSet() {
  LoadLocal(EBX, 2);  // Index.
  LoadLocal(ECX, 3);  // List.

  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(NOT_ZERO, &intrinsic_failure_);
  __ cmpl(EBX, Immediate(0));
  __ j(LESS, &intrinsic_failure_);

  // Load the backing store (array) from the first instance field of the list.
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EDX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  // Check the index against the length.
  __ cmpl(EBX, EDX);
  __ j(GREATER_EQUAL, &intrinsic_failure_);

  // Free up EBX, as we need the result (setter value) there.
  __ movl(EAX, EBX);

  // Store to the array and continue.
  ASSERT(Smi::kTagSize == 1);
  LoadLocal(EBX, 1);
  // Index (in EAX) is already smi-taged, so only scale by TIMES_2.
  __ movl(Address(ECX, EAX, TIMES_2, Array::kSize - HeapObject::kTag), EBX);

  AddToRememberedSetSlow(ECX, EBX, EAX);

  __ movl(EAX, EBX);
  __ ret();
}

void InterpreterGeneratorX86::DoIntrinsicListLength() {
  // Load the backing store (array) from the first instance field of the list.
  LoadLocal(ECX, 1);  // List.
  __ movl(ECX, Address(ECX, Instance::kSize - HeapObject::kTag));
  __ movl(EAX, Address(ECX, Array::kLengthOffset - HeapObject::kTag));

  __ ret();
}

void InterpreterGeneratorX86::Push(Register reg) { __ pushl(reg); }

void InterpreterGeneratorX86::Pop(Register reg) { __ popl(reg); }

void InterpreterGeneratorX86::Drop(int n) {
  __ addl(ESP, Immediate(n * kWordSize));
}

void InterpreterGeneratorX86::Drop(Register reg) {
  __ leal(ESP, Address(ESP, reg, TIMES_WORD_SIZE));
}

void InterpreterGeneratorX86::LoadProgram(Register reg) {
  __ movl(reg, Address(EDI, Process::kProgramOffset));
}

void InterpreterGeneratorX86::LoadStaticsArray(Register reg) {
  __ movl(reg, Address(EDI, Process::kStaticsOffset));
}

void InterpreterGeneratorX86::LoadLiteralNull(Register reg) {
  LoadProgram(reg);
  __ movl(reg, Address(reg, Program::kNullObjectOffset));
}

void InterpreterGeneratorX86::LoadLiteralTrue(Register reg) {
  LoadProgram(reg);
  __ movl(reg, Address(reg, Program::kTrueObjectOffset));
}

void InterpreterGeneratorX86::LoadLiteralFalse(Register reg) {
  LoadProgram(reg);
  __ movl(reg, Address(reg, Program::kFalseObjectOffset));
}

void InterpreterGeneratorX86::LoadNativeStack(Register reg) {
  __ movl(reg, Address(EDI, Process::kNativeStackOffset));
}

void InterpreterGeneratorX86::StoreNativeStack(Register reg) {
#ifdef DEBUG
  Label is_null;
  __ cmpl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
  __ j(EQUAL, &is_null);
  __ int3();
  __ Bind(&is_null);
#endif
  __ movl(Address(EDI, Process::kNativeStackOffset), reg);
}

void InterpreterGeneratorX86::SwitchToDartStack() {
  StoreNativeStack(ESP);
  __ movl(ESP, Address(ESP, spill_size_));
}

void InterpreterGeneratorX86::SwitchToCStack(Register scratch) {
  __ movl(scratch, ESP);
  LoadNativeStack(ESP);
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
  __ movl(Address(ESP, spill_size_), scratch);
}

void InterpreterGeneratorX86::StoreByteCodePointer() {
  __ movl(Address(EBP, -kWordSize), ESI);
}

void InterpreterGeneratorX86::RestoreByteCodePointer() {
  __ movl(ESI, Address(EBP, -kWordSize));
}

void InterpreterGeneratorX86::LoadLocal(Register reg, int index) {
  __ movl(reg, Address(ESP, index * kWordSize));
}

void InterpreterGeneratorX86::StoreLocal(Register reg, int index) {
  __ movl(Address(ESP, index * kWordSize), reg);
}

void InterpreterGeneratorX86::StoreLocal(const Immediate& value, int index) {
  __ movl(Address(ESP, index * kWordSize), value);
}

void InterpreterGeneratorX86::Return(bool is_return_null) {
  // Materialize the result in register EAX.
  if (is_return_null) {
    LoadLiteralNull(EAX);
  } else {
    LoadLocal(EAX, 0);
  }

  __ movl(ESP, EBP);
  __ popl(EBP);

  __ ret();
}

void InterpreterGeneratorX86::Allocate(bool immutable) {
  // Load the class into register ebx.
  __ movl(EAX, Address(ESI, 1));
  __ movl(EBX, Address(ESI, EAX, TIMES_1));

  const int kStackAllocateImmutable = 2 * kWordSize;
  const int kStackImmutableMembers = 3 * kWordSize;

  // We initialize the 4rd argument to "HandleAllocate" to 0, meaning the object
  // we're allocating will not be initialized with pointers to immutable space.
  // TODO(erikcorry): Simplify now that we don't have an immutable space.
  LoadNativeStack(ECX);
  __ movl(Address(ECX, kStackImmutableMembers), Immediate(0));

  // Loop over all arguments and find out if
  //   * all of them are immutable
  //   * there is at least one immutable member
  Label allocate;
  {
    // Initialization of [kStackAllocateImmutable] depended on [immutable]
    LoadNativeStack(ECX);
    __ movl(Address(ECX, kStackAllocateImmutable),
            Immediate(immutable ? 1 : 0));

    __ movl(ECX, Address(EBX, Class::kInstanceFormatOffset - HeapObject::kTag));
    __ andl(ECX, Immediate(InstanceFormat::FixedSizeField::mask()));
    int size_shift = InstanceFormat::FixedSizeField::shift() - kPointerSizeLog2;
    __ shrl(ECX, Immediate(size_shift));

    // ECX = SizeOfEntireObject - Instance::kSize
    __ subl(ECX, Immediate(Instance::kSize));

    // EDX = StackPointer(ESP) + NumberOfFields*kPointerSize
    __ movl(EDX, ESP);
    __ addl(EDX, ECX);

    Label loop;
    Label loop_with_immutable_field;
    Label loop_with_mutable_field;

    // Decrement pointer to point to next field.
    __ Bind(&loop);
    __ subl(EDX, Immediate(kPointerSize));

    // Test whether EDX < ESP. If so we're done and it's immutable.
    __ cmpl(EDX, ESP);
    __ j(BELOW, &allocate);

    // If Smi, continue the loop.
    __ movl(ECX, Address(EDX));
    __ testl(ECX, Immediate(Smi::kTagMask));
    __ j(ZERO, &loop);

    // Load class of object we want to test immutability of.
    __ movl(EAX, Address(ECX, HeapObject::kClassOffset - HeapObject::kTag));

    // Load instance format & handle the three cases:
    //  - never immutable (based on instance format) => not immutable
    //  - always immutable (based on instance format) => immutable
    //  - else (only instances) => check runtime-tracked bit
    uword mask = InstanceFormat::ImmutableField::mask();
    uword always_immutable_mask = InstanceFormat::ImmutableField::encode(
        InstanceFormat::ALWAYS_IMMUTABLE);
    uword never_immutable_mask =
        InstanceFormat::ImmutableField::encode(InstanceFormat::NEVER_IMMUTABLE);

    __ movl(EAX, Address(EAX, Class::kInstanceFormatOffset - HeapObject::kTag));
    __ andl(EAX, Immediate(mask));

    // If this is type never immutable we continue the loop.
    __ cmpl(EAX, Immediate(never_immutable_mask));
    __ j(EQUAL, &loop_with_mutable_field);

    // If this is type is always immutable we continue the loop.
    __ cmpl(EAX, Immediate(always_immutable_mask));
    __ j(EQUAL, &loop_with_immutable_field);

    // Else, we must have a Instance and check the runtime-tracked
    // immutable bit.
    uword im_mask = Instance::FlagsImmutabilityField::encode(true);
    __ movl(ECX, Address(ECX, Instance::kFlagsOffset - HeapObject::kTag));
    __ testl(ECX, Immediate(im_mask));
    __ j(NOT_ZERO, &loop_with_immutable_field);

    __ jmp(&loop_with_mutable_field);

    __ Bind(&loop_with_immutable_field);
    LoadNativeStack(EAX);
    __ movl(Address(EAX, kStackImmutableMembers), Immediate(1));
    __ jmp(&loop);

    __ Bind(&loop_with_mutable_field);
    LoadNativeStack(EAX);
    __ movl(Address(EAX, kStackAllocateImmutable), Immediate(0));
    __ jmp(&loop);
  }

  // TODO(kasperl): Consider inlining this in the interpreter.
  __ Bind(&allocate);
  SwitchToCStack(EAX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);
  // NOTE: The 3nd argument is already present ESP + kStackAllocateImmutable
  // NOTE: The 4rd argument is already present ESP + kStackImmutableMembers
  __ call("HandleAllocate");
  SwitchToDartStack();
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);

  __ movl(ECX, Address(EBX, Class::kInstanceFormatOffset - HeapObject::kTag));
  __ andl(ECX, Immediate(InstanceFormat::FixedSizeField::mask()));
  // The fixed size is recorded as the number of pointers. Therefore, the
  // size in bytes is the recorded size multiplied by kPointerSize. Instead
  // of doing the multiplication we shift by kPointerSizeLog2 less.
  ASSERT(InstanceFormat::FixedSizeField::shift() >= kPointerSizeLog2);
  int size_shift = InstanceFormat::FixedSizeField::shift() - kPointerSizeLog2;
  __ shrl(ECX, Immediate(size_shift));

  // Compute the address of the first and last instance field.
  __ leal(EDX, Address(EAX, ECX, TIMES_1, -1 * kWordSize - HeapObject::kTag));
  __ leal(ECX, Address(EAX, Instance::kSize - HeapObject::kTag));

  Label loop, done;
  __ Bind(&loop);
  __ cmpl(EDX, ECX);
  __ j(BELOW, &done);
  Pop(EBX);
  __ movl(Address(EDX, 0), EBX);
  __ subl(EDX, Immediate(1 * kWordSize));
  __ jmp(&loop);

  __ Bind(&done);
  Push(EAX);
  Dispatch(kAllocateLength);
}

void InterpreterGeneratorX86::AddToRememberedSetSlow(Register object,
                                                     Register value,
                                                     Register scratch) {
  // TODO(erikcorry): Implement remembered set.
}

void InterpreterGeneratorX86::InvokeMethodUnfold(bool test) {
  // Get the selector from the bytecodes.
  __ movl(EDX, Address(ESI, 1));

  if (test) {
    // Get the receiver from the stack.
    LoadLocal(EBX, 0);
  } else {
    // Compute the arity from the selector.
    ASSERT(Selector::ArityField::shift() == 0);
    __ movl(EBX, EDX);
    __ andl(EBX, Immediate(Selector::ArityField::mask()));

    // Get the receiver from the stack.
    __ movl(EBX, Address(ESP, EBX, TIMES_WORD_SIZE));
  }

  // Compute the receiver class.
  Label smi, probe;
  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &smi);
  __ movl(EBX, Address(EBX, HeapObject::kClassOffset - HeapObject::kTag));

  // Find the entry in the primary lookup cache.
  Label miss, finish;
  ASSERT(Utils::IsPowerOfTwo(LookupCache::kPrimarySize));
  ASSERT(sizeof(LookupCache::Entry) == 1 << 4);
  __ Bind(&probe);
  __ movl(EAX, EBX);
  __ xorl(EAX, EDX);
  __ andl(EAX, Immediate(LookupCache::kPrimarySize - 1));
  __ shll(EAX, Immediate(4));
  __ movl(ECX, Address(EDI, Process::kPrimaryLookupCacheOffset));
  __ addl(EAX, ECX);

  // Validate the primary entry.
  __ cmpl(EBX, Address(EAX, LookupCache::kClassOffset));
  __ j(NOT_EQUAL, &miss);
  __ cmpl(EDX, Address(EAX, LookupCache::kSelectorOffset));
  __ j(NOT_EQUAL, &miss);

  // At this point, we've got our hands on a valid lookup cache entry.
  __ Bind(&finish);

  if (test) {
    __ movl(EAX, Address(EAX, LookupCache::kCodeOffset));
  } else {
    __ movl(EBX, Address(EAX, LookupCache::kCodeOffset));
    __ movl(EAX, Address(EAX, LookupCache::kTargetOffset));

    __ testl(EBX, EBX);

    __ LoadLabel(ECX, "InterpreterMethodEntry");
    __ cmove(EBX, ECX);
  }

  if (test) {
    // Materialize either true or false depending on whether or not
    // we've found a target method.
    Label found;
    LoadProgram(EBX);
    __ testl(EAX, EAX);
    __ j(NOT_ZERO, &found);

    __ movl(EAX, Address(EBX, Program::kFalseObjectOffset));
    StoreLocal(EAX, 0);
    Dispatch(kInvokeTestUnfoldLength);

    __ Bind(&found);
    __ movl(EAX, Address(EBX, Program::kTrueObjectOffset));
    StoreLocal(EAX, 0);
    Dispatch(kInvokeTestUnfoldLength);
  } else {
    StoreByteCodePointer();
    __ call(EBX);
    RestoreByteCodePointer();

    __ movl(EDX, Address(ESI, 1));
    ASSERT(Selector::ArityField::shift() == 0);
    __ andl(EDX, Immediate(Selector::ArityField::mask()));

    Drop(EDX);

    StoreLocal(EAX, 0);
    Dispatch(kInvokeMethodUnfoldLength);
  }

  __ Bind(&smi);
  LoadProgram(EBX);
  __ movl(EBX, Address(EBX, Program::kSmiClassOffset));
  __ jmp(&probe);

  // We didn't find a valid entry in primary lookup cache.
  __ Bind(&miss);
  SwitchToCStack(ECX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ movl(Address(ESP, 2 * kWordSize), EBX);
  __ movl(Address(ESP, 3 * kWordSize), EDX);
  __ call("HandleLookupEntry");
  SwitchToDartStack();
  __ jmp(&finish);
}

void InterpreterGeneratorX86::InvokeMethod(bool test) {
  // Get the selector from the bytecodes.
  __ movl(EDX, Address(ESI, 1));

  // Fetch the dispatch table from the program.
  LoadProgram(ECX);
  __ movl(ECX, Address(ECX, Program::kDispatchTableOffset));

  if (!test) {
    // Compute the arity from the selector.
    ASSERT(Selector::ArityField::shift() == 0);
    __ movl(EBX, EDX);
    __ andl(EBX, Immediate(Selector::ArityField::mask()));
  }

  // Compute the selector offset (smi tagged) from the selector.
  __ andl(EDX, Immediate(Selector::IdField::mask()));
  __ shrl(EDX, Immediate(Selector::IdField::shift() - Smi::kTagSize));

  // Get the receiver from the stack.
  if (test) {
    LoadLocal(EBX, 0);
  } else {
    __ movl(EBX, Address(ESP, EBX, TIMES_WORD_SIZE));
  }

  // Compute the receiver class.
  Label smi, dispatch;
  ASSERT(Smi::kTag == 0);
  __ testl(EBX, Immediate(Smi::kTagMask));
  __ j(ZERO, &smi);
  __ movl(EBX, Address(EBX, HeapObject::kClassOffset - HeapObject::kTag));

  // Compute entry index: class id + selector offset.
  int id_offset = Class::kIdOrTransformationTargetOffset - HeapObject::kTag;
  __ Bind(&dispatch);
  __ movl(EBX, Address(EBX, id_offset));
  __ addl(EBX, EDX);

  // Fetch the entry from the table. Because the index is smi tagged
  // we only multiply by two -- not four -- when indexing.
  ASSERT(Smi::kTagSize == 1);
  __ movl(ECX, Address(ECX, EBX, TIMES_2, Array::kSize - HeapObject::kTag));

  // Validate that the offset stored in the entry matches the offset
  // we used to find it.
  Label invalid;
  __ cmpl(EDX,
          Address(ECX, DispatchTableEntry::kOffsetOffset - HeapObject::kTag));
  __ j(NOT_EQUAL, &invalid);

  Label validated;
  if (test) {
    // Valid entry: The answer is true.
    LoadLiteralTrue(EAX);
    StoreLocal(EAX, 0);
    Dispatch(kInvokeTestLength);
  } else {
    // Load the target from the entry.
    __ Bind(&validated);

    __ movl(EAX,
            Address(ECX, DispatchTableEntry::kTargetOffset - HeapObject::kTag));
    __ movl(ECX,
            Address(ECX, DispatchTableEntry::kCodeOffset - HeapObject::kTag));

    StoreByteCodePointer();
    // Test if the branch is a "default" call to InterpreterMethodEntry. If it
    // is, we use another call point, to help branch prediction.
    __ LoadLabel(EBX, "InterpreterMethodEntry");
    __ cmpl(ECX, EBX);
    Label default_call, resume;
    __ j(EQUAL, &default_call);
    __ call(ECX);
    __ Bind(&resume);
    RestoreByteCodePointer();

    __ movl(EDX, Address(ESI, 1));
    ASSERT(Selector::ArityField::shift() == 0);
    __ andl(EDX, Immediate(Selector::ArityField::mask()));

    Drop(EDX);

    StoreLocal(EAX, 0);
    Dispatch(kInvokeMethodLength);

    __ Bind(&default_call);
    __ call(EBX);
    __ jmp(&resume);
  }

  __ Bind(&smi);
  LoadProgram(EBX);
  __ movl(EBX, Address(EBX, Program::kSmiClassOffset));
  __ jmp(&dispatch);

  if (test) {
    // Invalid entry: The answer is false.
    __ Bind(&invalid);
    LoadLiteralFalse(EAX);
    StoreLocal(EAX, 0);
    Dispatch(kInvokeTestLength);
  } else {
    // Invalid entry: Use the noSuchMethod entry from entry zero of
    // the virtual table.
    __ Bind(&invalid);
    LoadProgram(ECX);
    __ movl(ECX, Address(ECX, Program::kDispatchTableOffset));
    __ movl(ECX, Address(ECX, Array::kSize - HeapObject::kTag));
    __ jmp(&validated);
  }
}

void InterpreterGeneratorX86::InvokeStatic() {
  __ movl(EAX, Address(ESI, 1));
  __ movl(EAX, Address(ESI, EAX, TIMES_1));

  StoreByteCodePointer();
  __ call("InterpreterMethodEntry");
  RestoreByteCodePointer();

  __ movl(EDX, Address(ESI, 1));
  __ movl(EDX, Address(ESI, EDX, TIMES_1));

  // Read the arity from the function. Note that the arity is smi tagged.
  __ movl(EDX, Address(EDX, Function::kArityOffset - HeapObject::kTag));
  __ shrl(EDX, Immediate(Smi::kTagSize));

  Drop(EDX);

  Push(EAX);
  Dispatch(kInvokeStaticLength);
}

void InterpreterGeneratorX86::InvokeCompare(const char* fallback,
                                            Condition condition) {
  LoadLocal(EAX, 0);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 1);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  Label true_case;
  __ cmpl(EBX, EAX);
  __ j(condition, &true_case);

  LoadLiteralFalse(EAX);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(5);

  __ Bind(&true_case);
  LoadLiteralTrue(EAX);
  StoreLocal(EAX, 1);
  Drop(1);
  Dispatch(5);
}

void InterpreterGeneratorX86::InvokeDivision(const char* fallback,
                                             bool quotient) {
  LoadLocal(EAX, 1);
  __ testl(EAX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);
  LoadLocal(EBX, 0);
  __ testl(EBX, Immediate(Smi::kTagSize));
  __ j(NOT_ZERO, fallback);

  // Check for division by zero.
  __ testl(EBX, EBX);
  __ j(ZERO, fallback);

  // Untag and sign extend eax into edx:eax.
  __ sarl(EAX, Immediate(1));
  __ sarl(EBX, Immediate(1));
  __ cdq();

  // Divide edx:eax by ebx. The resulting quotient and remainder are in
  // registers eax and edx respectively.
  __ idiv(EBX);

  // Re-tag. We need to check for overflow to handle the case
  // where the top two bits are 01 after the division. This only
  // happens when you divide 0xc0000000 by 0xffffffff.
  ASSERT(Smi::kTagSize == 1 && Smi::kTag == 0);
  Register reg = quotient ? EAX : EDX;
  __ addl(reg, reg);
  __ j(OVERFLOW_, fallback);

  StoreLocal(reg, 1);
  Drop(1);
  Dispatch(kInvokeMethodLength);
}

void InterpreterGeneratorX86::InvokeNative(bool yield) {
  __ movzbl(EBX, Address(ESI, 1));
  __ movzbl(EAX, Address(ESI, 2));

  __ LoadNative(EAX, EAX);

  // Extract address for first argument (note we skip two empty slots).
  __ leal(EBX, Address(ESP, EBX, TIMES_WORD_SIZE, 2 * kWordSize));

  SwitchToCStack(ECX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EBX);

  Label failure;
  __ call(EAX);
  SwitchToDartStack();
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(EQUAL, &failure);

  // Result is now in eax.
  if (yield) {
    // If the result of calling the native is null, we don't yield.
    LoadLiteralNull(ECX);
    Label dont_yield;
    __ cmpl(EAX, ECX);
    __ j(EQUAL, &dont_yield);

    // Yield to the target port.
    LoadNativeStack(EBX);
    __ movl(ECX, Address(EBX, spill_size_ + 7 * kWordSize));
    __ movl(Address(ECX, 0), EAX);
    __ movl(EAX, Immediate(Interpreter::kTargetYield));

    SaveState(&dont_yield);
    __ jmp(&done_state_saved_);

    __ Bind(&dont_yield);

    LoadLiteralNull(EAX);
  }

  __ movl(ESP, EBP);
  __ popl(EBP);

  __ ret();

  // Failure: Check if it's a request to garbage collect. If not,
  // just continue running the failure block by dispatching to the
  // next bytecode.
  __ Bind(&failure);
  __ movl(ECX, EAX);
  __ andl(ECX, Immediate(Failure::kTagMask | Failure::kTypeMask));
  __ cmpl(ECX, Immediate(Failure::kTag));
  __ j(EQUAL, &gc_);

  // TODO(kasperl): This should be reworked. We shouldn't be calling
  // through the runtime system for something as simple as converting
  // a failure object to the corresponding heap object.
  SwitchToCStack(ECX);
  __ movl(Address(ESP, 0 * kWordSize), EDI);
  __ movl(Address(ESP, 1 * kWordSize), EAX);
  __ call("HandleObjectFromFailure");
  SwitchToDartStack();

  Push(EAX);
  Dispatch(kInvokeNativeLength);
}

void InterpreterGeneratorX86::CheckStackOverflow(int size) {
  __ movl(EBX, Address(EDI, Process::kStackLimitOffset));
  __ cmpl(ESP, EBX);
  if (size == 0) {
    __ j(BELOW_EQUAL, &check_stack_overflow_0_);
  } else {
    Label done;
    __ j(BELOW, &done);
    __ movl(EAX, Immediate(size));
    __ jmp(&check_stack_overflow_);
    __ Bind(&done);
  }
}

void InterpreterGeneratorX86::Dispatch(int size) {
  // Load the next bytecode through esi and dispatch to it.
  __ movzbl(EBX, Address(ESI, size));
  if (size > 0) {
    __ addl(ESI, Immediate(size));
  }
  __ jmp("Interpret_DispatchTable", EBX, TIMES_WORD_SIZE);
}

void InterpreterGeneratorX86::SaveState(Label* resume) {
  // Save the bytecode pointer at the bcp slot.
  StoreByteCodePointer();

  // Push resume address.
  __ movl(ECX, resume);
  Push(ECX);

  // Push frame pointer.
  Push(EBP);

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
  LoadNativeStack(ESP);
  __ movl(Address(EDI, Process::kNativeStackOffset), Immediate(0));
}

void InterpreterGeneratorX86::RestoreState() {
  StoreNativeStack(ESP);

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

  // Set the bcp from the stack.
  RestoreByteCodePointer();

  __ ret();
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_IA32
