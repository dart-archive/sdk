// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/interpreter.h"

#include <math.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/vm/frame.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/natives.h"
#include "src/vm/port.h"
#include "src/vm/process.h"

#define GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(var, exp) \
  Object* var = (exp);                                                   \
  if (var == Failure::retry_after_gc()) {                                \
    if (CollectGarbageIfNecessary()) {                                   \
      SaveState();                                                       \
      /* Signal the scheduler that we need an immutable heap GC. */      \
      return Interpreter::kImmutableAllocationFailure;                   \
    }                                                                    \
    /* Re-try interpreting the bytecode by re-dispatching. */            \
    DISPATCH();                                                          \
  }                                                                      \

namespace fletch {

const NativeFunction kNativeTable[] = {
#define N(e, c, n) &Native_##e,
  NATIVES_DO(N)
#undef N
};

class State {
 public:
  explicit State(Process* process)
      : process_(process),
        program_(process->program()) {
    RestoreState();
  }

  Process* process() const { return process_; }
  Program* program() const { return program_; }

  void SaveState() {
    StoreByteCodePointer(bcp_);
    // Push empty slot to make the saved state look like it has a bcp,
    // thus making the top frame indexing as other frames.
    Push(NULL);
    Push(reinterpret_cast<Object*>(fp_));
    process_->stack()->SetTopFromPointer(sp_);
  }

  void RestoreState() {
    Stack* stack = process_->stack();
    sp_ = stack->Pointer(stack->top());
    fp_ = reinterpret_cast<Object**>(Pop());
    // Pop the empty unused value.
    Pop();
    bcp_ = LoadByteCodePointer();
    StoreByteCodePointer(NULL);
    ASSERT(bcp_ != NULL);
  }

  // Bytecode pointer related operations.
  uint8 ReadByte(int offset) { return bcp_[offset]; }
  int ReadInt32(int offset) { return Utils::ReadInt32(bcp_ + offset); }

  void PrintBytecode() {
    Bytecode::Print(bcp_);
  }

  Opcode ReadOpcode() const {
    uint8 opcode = *bcp_;
#ifdef DEBUG
    if (opcode >= Bytecode::kNumBytecodes) {
      FATAL1("Failed to interpret. Bad bytecode (opcode = %d).", opcode);
    }
#endif
    return static_cast<Opcode>(opcode);
  }

  Object* ReadConstant() const { return Function::ConstantForBytecode(bcp_); }

  void Goto(uint8* bcp) { ASSERT(bcp != NULL); bcp_ = bcp; }
  void Advance(int delta) { bcp_ += delta; }
  uint8* ComputeByteCodePointer(int offset) { return bcp_ + offset; }

  void SetFramePointer(Object** fp) { ASSERT(fp != NULL); fp_ = fp; }

  // Stack pointer related operations.
  Object* Top() { return *sp_; }
  void SetTop(Object* value) { *sp_ = value; }

  Object* Local(int n) { return *(sp_ + n); }
  void SetLocal(int n, Object* value) { *(sp_ + n)  = value; }
  Object** LocalPointer(int n) { return sp_ + n; }

  Object* Pop() { return *(sp_++); }
  void Push(Object* value) { *(--sp_) = value; }
  void Drop(int n) { sp_ += n; }

  bool HasStackSpaceFor(int size) const {
    return (sp_ - size) > reinterpret_cast<Object**>(process_->stack_limit());
  }

  Function* ComputeCurrentFunction() {
    return Function::FromBytecodePointer(bcp_);
  }

  void PushFrameDescriptor(int offset) {
    // Store the return address in the current frame.
    ASSERT(LoadByteCodePointer() == NULL);
    StoreByteCodePointer(ComputeByteCodePointer(offset));

    Push(NULL);
    Push(reinterpret_cast<Object*>(fp_));
    fp_ = sp_;
    Push(NULL);
  }

  void PopFrameDescriptor() {
    sp_ = fp_;
    fp_ = reinterpret_cast<Object**>(Pop());
    Pop();

    Goto(LoadByteCodePointer());
    StoreByteCodePointer(NULL);
  }

  void StoreByteCodePointer(uint8* bcp) {
    *(fp_ - 1) = reinterpret_cast<Object*>(bcp);
  }

  uint8* LoadByteCodePointer() {
    return reinterpret_cast<uint8*>(*(fp_ - 1));
  }

  Object** fp() { return fp_; }

 protected:
  uint8* bcp() { return bcp_; }
  Object** sp() { return sp_; }

 private:
  Process* const process_;
  Program* const program_;
  Object** sp_;
  Object** fp_;
  uint8* bcp_;
};

// TODO(kasperl): Should we call this interpreter?
class Engine : public State {
 public:
  explicit Engine(Process* process) : State(process) { }

  Interpreter::InterruptKind Interpret(TargetYieldResult* target_yield_result);

 private:
  void Branch(int true_offset, int false_offset);

  void PushDelta(int delta);
  int PopDelta();

  // If the result is different from |Process::kStackCheckContinue|,
  // |SaveState| will have been called. If the result is
  // |Process::kStackCheckContinue| the state will have been restored
  // and execution can continue directly.
  Process::StackCheckResult StackOverflowCheck(int size);

  // Throws exception. Expects SaveState to have been called. Returns
  // true if the exception was caught and false if the exception was
  // uncaught.
  bool DoThrow(Object* exception);

  // Returns `true` if the interpretation should stop and we should signal to
  // the scheduler that immutable garbage should be collected.
  bool CollectGarbageIfNecessary();
  void CollectMutableGarbage();

  void ValidateStack();

  bool ShouldBreak();
  bool IsAtBreakPoint();

  Object* ToBool(bool value) const {
    return value ? program()->true_object() : program()->false_object();
  }
};

#define STACK_OVERFLOW_CHECK(size)                                       \
  do {                                                                   \
    Process::StackCheckResult result = StackOverflowCheck(size);         \
    if (result != Process::kStackCheckContinue) {                        \
      if (result == Process::kStackCheckInterrupt) {                     \
        return Interpreter::kInterrupt;                                  \
      }                                                                  \
      if (result == Process::kStackCheckDebugInterrupt) {                \
        return Interpreter::kBreakPoint;                                 \
      }                                                                  \
      if (result == Process::kStackCheckOverflow) {                      \
        Object* exception = program()->stack_overflow_error();           \
        if (!DoThrow(exception)) return Interpreter::kUncaughtException; \
        DISPATCH();                                                      \
      }                                                                  \
    }                                                                    \
  } while (false);

#define DISPATCH()                                        \
  if (ShouldBreak()) return Interpreter::kBreakPoint;     \
  goto *kDispatchTable[ReadOpcode()]
#define DISPATCH_NO_BREAK()                               \
  goto *kDispatchTable[ReadOpcode()]
#define DISPATCH_TO(opcode)                               \
  goto opcode##Label

// Opcode definition macros.
#define OPCODE_BEGIN(opcode)                              \
  opcode##Label: {                                        \
    if (Flags::validate_stack) ValidateStack()
#define OPCODE_END() }                                    \
  DISPATCH()

Interpreter::InterruptKind Engine::Interpret(
    TargetYieldResult* target_yield_result) {
#define LABEL(name, branching, format, length, stack_diff, print) &&name##Label, // NOLINT
  static void* kDispatchTable[] = {
    BYTECODES_DO(LABEL)
  };
#undef LABEL

  // Dispatch to the first bytecode.
  if (IsAtBreakPoint()) {
    DISPATCH_NO_BREAK();
  } else {
    DISPATCH();
  }

  OPCODE_BEGIN(LoadLocal0);
    Object* local = Local(0);
    Push(local);
    Advance(kLoadLocal0Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal1);
    Object* local = Local(1);
    Push(local);
    Advance(kLoadLocal1Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal2);
    Object* local = Local(2);
    Push(local);
    Advance(kLoadLocal2Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal3);
    Object* local = Local(3);
    Push(local);
    Advance(kLoadLocal3Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal4);
    Object* local = Local(4);
    Push(local);
    Advance(kLoadLocal4Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal5);
    Object* local = Local(5);
    Push(local);
    Advance(kLoadLocal5Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocal);
    int offset = ReadByte(1);
    Object* local = Local(offset);
    Push(local);
    Advance(kLoadLocalLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadLocalWide);
    int offset = ReadInt32(1);
    Object* local = Local(offset);
    Push(local);
    Advance(kLoadLocalWideLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadBoxed);
    int offset = ReadByte(1);
    Boxed* boxed = Boxed::cast(Local(offset));
    Push(boxed->value());
    Advance(kLoadBoxedLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadStatic);
    int index = ReadInt32(1);
    Object* value = process()->statics()->get(index);
    Push(value);
    Advance(kLoadStaticLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadStaticInit);
    int index = ReadInt32(1);
    Object* value = process()->statics()->get(index);
    if (value->IsInitializer()) {
      Function* target = Initializer::cast(value)->function();
      PushFrameDescriptor(kLoadStaticInitLength);
      Goto(target->bytecode_address_for(0));
      STACK_OVERFLOW_CHECK(0);
    } else {
      Push(value);
      Advance(kLoadStaticInitLength);
    }
  OPCODE_END();

  OPCODE_BEGIN(LoadField);
    Instance* target = Instance::cast(Pop());
    Push(target->GetInstanceField(ReadByte(1)));
    Advance(kLoadFieldLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadFieldWide);
    Instance* target = Instance::cast(Pop());
    Push(target->GetInstanceField(ReadInt32(1)));
    Advance(kLoadFieldWideLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadConst);
    int index = ReadInt32(1);
    Push(program()->constant_at(index));
    Advance(kLoadConstLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadConstUnfold);
    Push(ReadConstant());
    Advance(kLoadConstUnfoldLength);
  OPCODE_END();

  OPCODE_BEGIN(StoreLocal);
    int offset = ReadByte(1);
    Object* value = Local(0);
    SetLocal(offset, value);
    Advance(kStoreLocalLength);
  OPCODE_END();

  OPCODE_BEGIN(StoreBoxed);
    int offset = ReadByte(1);
    Object* value = Local(0);
    Boxed* boxed = Boxed::cast(Local(offset));
    boxed->set_value(value);

    if (value->IsHeapObject() && value->IsImmutable()) {
      process()->store_buffer()->Insert(boxed);
    }

    Advance(kStoreBoxedLength);
  OPCODE_END();

  OPCODE_BEGIN(StoreStatic);
    int index = ReadInt32(1);
    Object* value = Local(0);
    Array* statics = process()->statics();
    statics->set(index, value);

    if (value->IsHeapObject() && value->IsImmutable()) {
      process()->store_buffer()->Insert(statics);
    }

    Advance(kStoreStaticLength);
  OPCODE_END();

  OPCODE_BEGIN(StoreField);
    Object* value = Pop();
    Instance* target = Instance::cast(Pop());
    ASSERT(!target->IsImmutable());
    target->SetInstanceField(ReadByte(1), value);
    Push(value);
    Advance(kStoreFieldLength);

    if (value->IsHeapObject() && value->IsImmutable()) {
      process()->store_buffer()->Insert(target);
    }
  OPCODE_END();

  OPCODE_BEGIN(StoreFieldWide);
    Object* value = Pop();
    Instance* target = Instance::cast(Pop());
    target->SetInstanceField(ReadInt32(1), value);
    Push(value);
    Advance(kStoreFieldWideLength);

    if (value->IsHeapObject() && value->IsImmutable()) {
      process()->store_buffer()->Insert(target);
    }
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteralNull);
    Push(program()->null_object());
    Advance(kLoadLiteralNullLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteralTrue);
    Push(program()->true_object());
    Advance(kLoadLiteralTrueLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteralFalse);
    Push(program()->false_object());
    Advance(kLoadLiteralFalseLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteral0);
    Push(Smi::FromWord(0));
    Advance(kLoadLiteral0Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteral1);
    Push(Smi::FromWord(1));
    Advance(kLoadLiteral1Length);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteral);
    Push(Smi::FromWord(ReadByte(1)));
    Advance(kLoadLiteralLength);
  OPCODE_END();

  OPCODE_BEGIN(LoadLiteralWide);
    int value = ReadInt32(1);
    ASSERT(Smi::IsValid(value));
    Push(Smi::FromWord(value));
    Advance(kLoadLiteralWideLength);
  OPCODE_END();

  OPCODE_BEGIN(InvokeMethodUnfold);
    int selector = ReadInt32(1);
    int arity = Selector::ArityField::decode(selector);
    Object* receiver = Local(arity);
    PushFrameDescriptor(kInvokeMethodUnfoldLength);
    Function* target = process()->LookupEntry(receiver, selector)->target;
    Goto(target->bytecode_address_for(0));
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeSelector);
    SaveState();
    HandleInvokeSelector(process());
    RestoreState();
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeNoSuchMethod);
    Array* entry = Array::cast(program()->dispatch_table()->get(0));
    Function* target = Function::cast(entry->get(2));
    PushFrameDescriptor(kInvokeNoSuchMethodLength);
    Goto(target->bytecode_address_for(0));
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeTestNoSuchMethod);
    SetLocal(0, program()->false_object());
    Advance(kInvokeTestNoSuchMethodLength);
  OPCODE_END();

  OPCODE_BEGIN(InvokeMethod);
    int selector = ReadInt32(1);
    int arity = Selector::ArityField::decode(selector);
    int offset = Selector::IdField::decode(selector);
    Object* receiver = Local(arity);
    PushFrameDescriptor(kInvokeMethodLength);

    Class* clazz = receiver->IsSmi()
        ? program()->smi_class()
        : HeapObject::cast(receiver)->get_class();

    int index = clazz->id() + offset;
    Array* entry = Array::cast(program()->dispatch_table()->get(index));
    if (Smi::cast(entry->get(0))->value() != offset) {
      entry = Array::cast(program()->dispatch_table()->get(0));
    }
    Function* target = Function::cast(entry->get(2));
    Goto(target->bytecode_address_for(0));
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeStatic);
    int index = ReadInt32(1);
    Function* target = program()->static_method_at(index);
    PushFrameDescriptor(kInvokeStaticLength);
    Goto(target->bytecode_address_for(0));
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeFactory);
    DISPATCH_TO(InvokeStatic);
  OPCODE_END();

  OPCODE_BEGIN(InvokeStaticUnfold);
    Function* target = Function::cast(ReadConstant());
    PushFrameDescriptor(kInvokeStaticLength);
    Goto(target->bytecode_address_for(0));
    STACK_OVERFLOW_CHECK(0);
  OPCODE_END();

  OPCODE_BEGIN(InvokeFactoryUnfold);
    DISPATCH_TO(InvokeStaticUnfold);
  OPCODE_END();

  OPCODE_BEGIN(InvokeNative);
    int arity = ReadByte(1);
    Native native = static_cast<Native>(ReadByte(2));
    Object** arguments = LocalPointer(arity + 2);
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, kNativeTable[native](process(), Arguments(arguments)));
    if (result->IsFailure()) {
      Push(program()->ObjectFromFailure(Failure::cast(result)));
      Advance(kInvokeNativeLength);
    } else {
      PopFrameDescriptor();
      Drop(arity);
      Push(result);
    }
  OPCODE_END();

#define INVOKE_BUILTIN(kind)           \
  OPCODE_BEGIN(Invoke##kind##Unfold);  \
    DISPATCH_TO(InvokeMethodUnfold);   \
  OPCODE_END();                        \
  OPCODE_BEGIN(Invoke##kind);          \
    DISPATCH_TO(InvokeMethod);         \
  OPCODE_END();

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

  OPCODE_BEGIN(InvokeNativeYield);
    int arity = ReadByte(1);
    Native native = static_cast<Native>(ReadByte(2));
    Object** arguments = LocalPointer(arity + 2);
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, kNativeTable[native](process(), Arguments(arguments)));
    if (result->IsFailure()) {
      Push(program()->ObjectFromFailure(Failure::cast(result)));
      Advance(kInvokeNativeYieldLength);
    } else {
      PopFrameDescriptor();
      Drop(arity);
      Object* null = program()->null_object();
      Push(null);
      if (result != null) {
        SaveState();
        *target_yield_result = TargetYieldResult(result);
        ASSERT((*target_yield_result).port()->IsLocked());
        return Interpreter::kTargetYield;
      }
    }
  OPCODE_END();

  OPCODE_BEGIN(InvokeTestUnfold);
    int selector = ReadInt32(1);
    Object* receiver = Local(0);
    SetTop(ToBool(process()->LookupEntry(receiver, selector)->tag != 0));
    Advance(kInvokeTestUnfoldLength);
  OPCODE_END();

  OPCODE_BEGIN(InvokeTest);
    int selector = ReadInt32(1);
    int offset = Selector::IdField::decode(selector);
    Object* receiver = Local(0);

    Class* clazz = receiver->IsSmi()
        ? program()->smi_class()
        : HeapObject::cast(receiver)->get_class();

    int index = clazz->id() + offset;
    Array* entry = Array::cast(program()->dispatch_table()->get(index));
    SetTop(ToBool(Smi::cast(entry->get(0))->value() == offset));

    Advance(kInvokeTestLength);
  OPCODE_END();

  OPCODE_BEGIN(Pop);
    Drop(1);
    Advance(kPopLength);
  OPCODE_END();

  OPCODE_BEGIN(Drop);
    int argument = ReadByte(1);
    Drop(argument);
    Advance(kDropLength);
  OPCODE_END();

  OPCODE_BEGIN(Return);
    int arguments = ReadByte(1);
    Object* result = Local(0);
    PopFrameDescriptor();
    Drop(arguments);
    Push(result);
  OPCODE_END();

  OPCODE_BEGIN(ReturnNull);
    int arguments = ReadByte(1);
    PopFrameDescriptor();
    Drop(arguments);
    Push(program()->null_object());
  OPCODE_END();

  OPCODE_BEGIN(BranchWide);
    int delta = ReadInt32(1);
    Advance(delta);
  OPCODE_END();

  OPCODE_BEGIN(BranchIfTrueWide);
    int delta = ReadInt32(1);
    Branch(delta, kBranchIfTrueWideLength);
  OPCODE_END();

  OPCODE_BEGIN(BranchIfFalseWide);
    int delta = ReadInt32(1);
    Branch(kBranchIfFalseWideLength, delta);
  OPCODE_END();

  OPCODE_BEGIN(BranchBack);
    STACK_OVERFLOW_CHECK(0);
    Advance(-ReadByte(1));
  OPCODE_END();

  OPCODE_BEGIN(BranchBackIfTrue);
    STACK_OVERFLOW_CHECK(0);
    int delta = -ReadByte(1);
    Branch(delta, kBranchBackIfTrueLength);
  OPCODE_END();

  OPCODE_BEGIN(BranchBackIfFalse);
    STACK_OVERFLOW_CHECK(0);
    int delta = -ReadByte(1);
    Branch(kBranchBackIfTrueLength, delta);
  OPCODE_END();

  OPCODE_BEGIN(BranchBackWide);
    STACK_OVERFLOW_CHECK(0);
    int delta = ReadInt32(1);
    Advance(-delta);
  OPCODE_END();

  OPCODE_BEGIN(BranchBackIfTrueWide);
    STACK_OVERFLOW_CHECK(0);
    int delta = -ReadInt32(1);
    Branch(delta, kBranchBackIfTrueWideLength);
  OPCODE_END();

  OPCODE_BEGIN(BranchBackIfFalseWide);
    STACK_OVERFLOW_CHECK(0);
    int delta = -ReadInt32(1);
    Branch(kBranchBackIfFalseWideLength, delta);
  OPCODE_END();

  OPCODE_BEGIN(PopAndBranchWide);
    int pop_count = ReadByte(1);
    int delta = ReadInt32(2);
    Drop(pop_count);
    Advance(delta);
  OPCODE_END();

  OPCODE_BEGIN(PopAndBranchBackWide);
    STACK_OVERFLOW_CHECK(0);
    int pop_count = ReadByte(1);
    int delta = -ReadInt32(2);
    Drop(pop_count);
    Advance(delta);
  OPCODE_END();

  OPCODE_BEGIN(Allocate);
    int index = ReadInt32(1);
    Class* klass = program()->class_at(index);
    ASSERT(klass->id() == index);
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, process()->NewInstance(klass));
    Instance* instance = Instance::cast(result);
    int fields = klass->NumberOfInstanceFields();
    bool in_store_buffer = false;
    for (int i = fields - 1; i >= 0; --i) {
      Object* value = Pop();
      if (!in_store_buffer &&
          value->IsImmutable() &&
          value->IsHeapObject()) {
        in_store_buffer = true;
        process()->store_buffer()->Insert(instance);
      }
      instance->SetInstanceField(i, value);
    }
    Push(instance);
    Advance(kAllocateLength);
  OPCODE_END();

  OPCODE_BEGIN(AllocateUnfold);
    Class* klass = Class::cast(ReadConstant());
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, process()->NewInstance(klass));
    Instance* instance = Instance::cast(result);
    int fields = klass->NumberOfInstanceFields();
    bool in_store_buffer = false;
    for (int i = fields - 1; i >= 0; --i) {
      Object* value = Pop();
      if (!in_store_buffer &&
          value->IsImmutable() &&
          value->IsHeapObject()) {
        in_store_buffer = true;
        process()->store_buffer()->Insert(instance);
      }
      instance->SetInstanceField(i, value);
    }
    Push(instance);
    Advance(kAllocateLength);
  OPCODE_END();

  OPCODE_BEGIN(AllocateImmutable);
    int index = ReadInt32(1);
    Class* klass = program()->class_at(index);
    ASSERT(klass->id() == index);
    int fields = klass->NumberOfInstanceFields();
    bool immutable = true;
    bool has_immutable_pointers = false;
    for (int i = 0; i < fields; i++) {
      Object* local = Local(i);
      if (!local->IsImmutable()) {
        immutable = false;
      } else if (local->IsHeapObject()) {
        has_immutable_pointers = true;
      }
    }
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, process()->NewInstance(klass, immutable));
    Instance* instance = Instance::cast(result);
    for (int i = fields - 1; i >= 0; --i) {
      Object* value = Pop();
      instance->SetInstanceField(i, value);
    }
    Push(instance);

    if (!immutable && has_immutable_pointers) {
      process()->store_buffer()->Insert(instance);
    }

    Advance(kAllocateImmutableLength);
  OPCODE_END();

  OPCODE_BEGIN(AllocateImmutableUnfold);
    Class* klass = Class::cast(ReadConstant());
    int fields = klass->NumberOfInstanceFields();
    bool immutable = true;
    bool has_immutable_pointers = false;
    for (int i = 0; i < fields; i++) {
      Object* local = Local(i);
      if (!local->IsImmutable()) {
        immutable = false;
      } else if (local->IsHeapObject()) {
        has_immutable_pointers = true;
      }
    }
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        result, process()->NewInstance(klass, immutable));
    Instance* instance = Instance::cast(result);
    for (int i = fields - 1; i >= 0; --i) {
      Object* value = Pop();
      instance->SetInstanceField(i, value);
    }
    Push(instance);

    if (!immutable && has_immutable_pointers) {
      process()->store_buffer()->Insert(instance);
    }

    Advance(kAllocateImmutableUnfoldLength);
  OPCODE_END();

  OPCODE_BEGIN(AllocateBoxed);
    Object* value = Local(0);
    GC_AND_RETRY_ON_ALLOCATION_FAILURE_OR_SIGNAL_SCHEDULER(
        raw_boxed, HandleAllocateBoxed(process(), value));
    Boxed* boxed = Boxed::cast(raw_boxed);
    SetTop(boxed);
    Advance(kAllocateBoxedLength);
  OPCODE_END();

  OPCODE_BEGIN(Negate);
    Object* condition = Local(0);
    if (condition == program()->true_object()) {
      SetTop(program()->false_object());
    } else {
      SetTop(program()->true_object());
    }
    Advance(kNegateLength);
  OPCODE_END();

  OPCODE_BEGIN(StackOverflowCheck);
    int size = ReadInt32(1);
    STACK_OVERFLOW_CHECK(size);
    Advance(kStackOverflowCheckLength);
  OPCODE_END();

  OPCODE_BEGIN(Throw);
    // TODO(kasperl): We assume that the stack walker code will not
    // cause any GCs so it's safe to hold onto the exception reference.
    Object* exception = Local(0);

    // Push next address, to make the frame look complete.
    SaveState();

    if (!DoThrow(exception)) return Interpreter::kUncaughtException;
  OPCODE_END();

  OPCODE_BEGIN(ProcessYield);
    Object* value = Local(0);
    SetTop(program()->null_object());
    Advance(kProcessYieldLength);
    SaveState();
    return static_cast<Interpreter::InterruptKind>(Smi::cast(value)->value());
  OPCODE_END();

  OPCODE_BEGIN(CoroutineChange);
    Object* argument = Local(0);
    SetLocal(0, program()->null_object());
    Coroutine* coroutine = Coroutine::cast(Local(1));
    SetLocal(1, program()->null_object());

    SaveState();
    process()->UpdateCoroutine(coroutine);
    RestoreState();

    Advance(kCoroutineChangeLength);

    Drop(1);
    SetTop(argument);
  OPCODE_END();

  OPCODE_BEGIN(Identical);
    Object* result = HandleIdentical(process(), Local(1), Local(0));
    Drop(1);
    SetTop(result);
    Advance(kIdenticalLength);
  OPCODE_END();

  OPCODE_BEGIN(IdenticalNonNumeric);
    bool identical = Local(0) == Local(1);
    Drop(1);
    SetTop(ToBool(identical));
    Advance(kIdenticalNonNumericLength);
  OPCODE_END();

  OPCODE_BEGIN(EnterNoSuchMethod);
    SaveState();
    HandleEnterNoSuchMethod(process());
    RestoreState();
  OPCODE_END();

  OPCODE_BEGIN(ExitNoSuchMethod);
    Object* result = Pop();
    word selector = Smi::cast(Pop())->value();
    PopFrameDescriptor();

    // The result of invoking setters must be the assigned value,
    // even in the presence of noSuchMethod.
    if (Selector::KindField::decode(selector) == Selector::SETTER) {
      result = Local(0);
    }

    int arity = Selector::ArityField::decode(selector);
    Drop(arity + 1);
    Push(result);
  OPCODE_END();

  OPCODE_BEGIN(SubroutineCall);
    int delta = ReadInt32(1);
    int return_delta = ReadInt32(5);
    PushDelta(return_delta);
    Advance(delta);
  OPCODE_END();

  OPCODE_BEGIN(SubroutineReturn);
    Advance(-PopDelta());
  OPCODE_END();

  OPCODE_BEGIN(MethodEnd);
    FATAL("Cannot interpret 'method-end' bytecodes.");
  OPCODE_END();
} // NOLINT

void Engine::Branch(int true_offset, int false_offset) {
  int offset = (Pop() == program()->true_object())
      ? true_offset
      : false_offset;
  Advance(offset);
}

void Engine::PushDelta(int delta) {
  Push(Smi::FromWord(delta));
}

int Engine::PopDelta() {
  return Smi::cast(Pop())->value();
}

Process::StackCheckResult Engine::StackOverflowCheck(int size) {
  if (HasStackSpaceFor(size)) return Process::kStackCheckContinue;
  SaveState();
  Process::StackCheckResult result = process()->HandleStackOverflow(size);
  if (result == Process::kStackCheckContinue) RestoreState();
  return result;
}

bool Engine::DoThrow(Object* exception) {
  // Find the catch block address.
  int stack_delta = 0;
  Object** frame_pointer = NULL;
  uint8* catch_bcp = HandleThrow(process(),
                                 exception,
                                 &stack_delta,
                                 &frame_pointer);
  if (catch_bcp == NULL) return false;
  ASSERT(frame_pointer != NULL);
  // Restore stack pointer and bcp.
  RestoreState();
  SetFramePointer(frame_pointer);
  StoreByteCodePointer(NULL);
  Goto(catch_bcp);
  // The delta is computed given that bcp and fp is pushed on the
  // stack. We have already pop'ed bcp as part of RestoreState.
  Drop(stack_delta);
  SetTop(exception);
  return true;
}

bool Engine::CollectGarbageIfNecessary() {
  if (process()->heap()->needs_garbage_collection()) {
    CollectMutableGarbage();
  }
  return process()->immutable_heap()->needs_garbage_collection();
}

void Engine::CollectMutableGarbage() {
  SaveState();
  process()->CollectMutableGarbage();
  RestoreState();

  // After a mutable GC a lot of stacks might no longer have pointers to
  // immutable space on them. If so, the store buffer will no longer contain
  // such a stack.
  //
  // Since we don't update the store buffer on every mutating operation
  // - e.g. SetLocal() - we add it before we start using it.
  process()->store_buffer()->Insert(process()->stack());
}

void Engine::ValidateStack() {
  SaveState();
  Frame frame(process()->stack());
  while (frame.MovePrevious()) {
    frame.FunctionFromByteCodePointer();
    if (*(frame.FirstLocalAddress() + 1) != NULL) {
      FATAL("Expected empty slot");
    }
  }
  RestoreState();
}

bool Engine::ShouldBreak() {
  DebugInfo* debug_info = process()->debug_info();
  if (debug_info != NULL) {
    bool should_break = debug_info->ShouldBreak(bcp(), sp());
    if (should_break) SaveState();
    return should_break;
  }
  return false;
}

bool Engine::IsAtBreakPoint() {
  DebugInfo* debug_info = process()->debug_info();
  if (process()->debug_info() != NULL) {
    bool result = debug_info->is_at_breakpoint();
    debug_info->clear_current_breakpoint();
    return result;
  }
  return false;
}

void Interpreter::Run() {
  ASSERT(interruption_ == kReady);

  // TODO(ager): We might want to have a stack guard check here in
  // order to make sure that all interruptions active at a certain
  // stack guard check gets handled at the same bcp.

  process_->RestoreErrno();
  process_->TakeLookupCache();

  // Whenever we enter the interpreter, we might operate on a stack which
  // doesn't contain any references to immutable space. This means the
  // storebuffer might *NOT* contain the stack.
  //
  // Since we don't update the store buffer on every mutating operation - e.g.
  // SetLocal() - we add it as soon as the interpreter uses it:
  //   * once we enter the interpreter
  //   * once we we're done with mutable GC
  //   * once we we've done a coroutine change
  // This is conservative.
  process_->store_buffer()->Insert(process_->stack());

  int result = InterpretFast(process_, &target_yield_result_);
  if (result < 0) {
    interruption_ = HandleBailout();
  } else {
    interruption_ = static_cast<InterruptKind>(result);
  }

  process_->ReleaseLookupCache();
  process_->StoreErrno();
  ASSERT(interruption_ != kReady);
}

Interpreter::InterruptKind Interpreter::HandleBailout() {
#if !defined(FLETCH_ENABLE_LIVE_CODING) && \
    (defined(FLETCH_TARGET_IA32) || defined(FLETCH_TARGET_ARM))
  // When live coding is disabled on a fully supported platform, we don't
  // need to bundle in the slow interpreter.
  FATAL("Unsupported bailout from native interpreter");
  return kTerminate;
#else
  Engine engine(process_);
  return engine.Interpret(&target_yield_result_);
#endif
}

// -------------------- Native interpreter support --------------------

Process::StackCheckResult HandleStackOverflow(Process* process, int size) {
  return process->HandleStackOverflow(size);
}

int HandleGC(Process* process) {
  if (process->heap()->needs_garbage_collection()) {
    process->CollectMutableGarbage();

    // After a mutable GC a lot of stacks might no longer have pointers to
    // immutable space on them. If so, the store buffer will no longer contain
    // such a stack.
    //
    // Since we don't update the store buffer on every mutating operation
    // - e.g. SetLocal() - we add it before we start using it.
    process->store_buffer()->Insert(process->stack());
  }

  return process->immutable_heap()->needs_garbage_collection()
      ? 1
      : 0;
}

Object* HandleObjectFromFailure(Process* process, Failure* failure) {
  return process->program()->ObjectFromFailure(failure);
}

Object* HandleAllocate(Process* process,
                       Class* clazz,
                       int immutable,
                       int immutable_heapobject_member) {
  Object* result = process->NewInstance(clazz, immutable == 1);
  if (result->IsFailure()) return result;

  if (immutable != 1 && immutable_heapobject_member == 1) {
    process->store_buffer()->Insert(HeapObject::cast(result));
  }
  return result;
}

void AddToStoreBufferSlow(Process* process, Object* object, Object* value) {
  ASSERT(object->IsHeapObject());
  ASSERT(process->heap()->space()->Includes(
      HeapObject::cast(object)->address()));
  if (value->IsHeapObject() && value->IsImmutable()) {
    process->store_buffer()->Insert(HeapObject::cast(object));
  }
}

Object* HandleAllocateBoxed(Process* process, Object* value) {
  Object* boxed = process->NewBoxed(value);
  if (boxed->IsFailure()) return boxed;

  if (value->IsHeapObject() && !value->IsNull() && value->IsImmutable()) {
    process->store_buffer()->Insert(HeapObject::cast(boxed));
  }
  return boxed;
}

void HandleCoroutineChange(Process* process, Coroutine* coroutine) {
  process->UpdateCoroutine(coroutine);
}

Object* HandleIdentical(Process* process, Object* left, Object* right) {
  bool identical;
  if (left == right) {
    identical = true;
  } else if (left->IsDouble() && right->IsDouble()) {
    fletch_double_as_uint left_value =
        bit_cast<fletch_double_as_uint>(Double::cast(left)->value());
    fletch_double_as_uint right_value =
        bit_cast<fletch_double_as_uint>(Double::cast(right)->value());
    identical = (left_value == right_value);
  } else if (left->IsLargeInteger() && right->IsLargeInteger()) {
    int64 left_value = LargeInteger::cast(left)->value();
    int64 right_value = LargeInteger::cast(right)->value();
    identical = (left_value == right_value);
  } else {
    identical = false;
  }
  Program* program = process->program();
  return identical ? program->true_object() : program->false_object();
}

LookupCache::Entry* HandleLookupEntry(Process* process,
                                      LookupCache::Entry* primary,
                                      Class* clazz,
                                      int selector) {
  // TODO(kasperl): Can we inline the definition here? This is
  // performance critical.
  return process->LookupEntrySlow(primary, clazz, selector);
}

// Overlay this struct on the catch table to interpret the bytes.
struct CatchBlock {
  int start;
  int end;
  int frame_size;
};

static uint8* FindCatchBlock(Stack* stack,
                             int* stack_delta_result,
                             Object*** frame_pointer_result) {
  Frame frame(stack);
  while (frame.MovePrevious()) {
    int offset = -1;
    Function* function = frame.FunctionFromByteCodePointer(&offset);

    // Skip if there are no catch blocks.
    if (offset == -1) continue;

    uint8* bcp = frame.ByteCodePointer();
    uint8* catch_block_address = function->bytecode_address_for(offset);
    int count = Utils::ReadInt32(catch_block_address);
    const CatchBlock* block =
        reinterpret_cast<const CatchBlock*>(catch_block_address + 4);
    for (int i = 0; i < count; i++) {
      uint8* start_address = function->bytecode_address_for(block->start);
      uint8* end_address = function->bytecode_address_for(block->end);
      // The first hit is the one we use (due to the order they are
      // emitted).
      if (start_address < bcp && end_address > bcp) {
        // Read the number of stack slots we need to pop.
        int index = frame.FirstLocalIndex() - block->frame_size - 1;
        *stack_delta_result = index - stack->top();
        *frame_pointer_result = frame.FramePointer();
        return end_address;
      }
      block++;
    }
  }
  return NULL;
}


uint8* HandleThrow(Process* process,
                   Object* exception,
                   int* stack_delta_result,
                   Object*** frame_pointer_result) {
  Coroutine* current = process->coroutine();
  while (true) {
    // If we find a handler, we do a 2nd pass, unwind all coroutine stacks
    // until the handler, make the unused coroutines/stacks GCable and return
    // the handling bcp.
    uint8* catch_bcp = FindCatchBlock(
        current->stack(), stack_delta_result, frame_pointer_result);
    if (catch_bcp != NULL) {
      Coroutine* unused = process->coroutine();
      while (current != unused) {
        Coroutine* caller = unused->caller();
        unused->set_stack(process->program()->null_object());
        unused->set_caller(unused);
        unused = caller;
      }
      process->UpdateCoroutine(current);
      return catch_bcp;
    }

    if (!current->has_caller()) {
      break;
    }
    current = current->caller();
  }

  // If we haven't found a handler we leave the coroutine/stacks untouched and
  // signal that the exception was uncaught.
  process->set_exception(exception);
  return NULL;
}

void HandleEnterNoSuchMethod(Process* process) {
  Frame caller_frame(process->stack());

  // Navigate to the the frame that invoked the unresolved call.
  caller_frame.MovePrevious();
  caller_frame.MovePrevious();

  // TODO(ajohnsen): Make this work in a non-restored state?
  State state(process);

  Program* program = state.program();

  // Read the bcp address for the frame.
  uint8* bcp = caller_frame.ByteCodePointer();
  Opcode opcode = static_cast<Opcode>(*(bcp - 5));

  int selector;
  if (opcode == Opcode::kInvokeSelector) {
    // If we have nested noSuchMethod trampolines, the selector is located
    // in the caller frame, as the first argument.
    int call_selector = Smi::cast(*caller_frame.FirstLocalAddress())->value();

    // The selector that was used was not this selector, but instead a 'call'
    // selector with the same arity (see call_selector below).
    int arity = Selector::ArityField::decode(call_selector);
    selector = Selector::EncodeMethod(Names::kCall, arity);
  } else if (opcode == Opcode::kInvokeNoSuchMethod) {
    selector = Utils::ReadInt32(bcp - 4);
  } else if (Bytecode::IsInvoke(opcode)) {
    selector = Utils::ReadInt32(bcp - 4);
    int offset = Selector::IdField::decode(selector);
    for (int i = offset; true; i++) {
      Array* entry = Array::cast(program->dispatch_table()->get(i));
      if (Smi::cast(entry->get(0))->value() == offset) {
        selector = Smi::cast(entry->get(1))->value();
        break;
      }
    }
  } else {
    ASSERT(Bytecode::IsInvokeUnfold(opcode));
    selector = Utils::ReadInt32(bcp- 4);
  }

  int arity = Selector::ArityField::decode(selector);
  Smi* selector_smi = Smi::FromWord(selector);
  Object* receiver = state.Local(arity + 3);

  Class* clazz = receiver->IsSmi()
      ? program->smi_class()
      : HeapObject::cast(receiver)->get_class();

  // This value is used by exitNoSuchMethod to pop arguments and detect if
  // original selector was a setter.
  state.Push(selector_smi);

  int selector_id = Selector::IdField::decode(selector);
  int get_selector = Selector::EncodeGetter(selector_id);

  // TODO(ajohnsen): We need to ensure that the getter is not a tearoff getter.
  if (clazz->LookupMethod(get_selector) != NULL) {
    int call_selector = Selector::EncodeMethod(Names::kCall, arity);
    state.Push(program->null_object());
    for (int i = 0; i < arity; i++) {
      state.Push(state.Local(arity + 4));
    }
    state.Push(Smi::FromWord(call_selector));
    state.Push(program->null_object());
    state.Push(Smi::FromWord(get_selector));
    state.Push(receiver);
    state.Advance(kEnterNoSuchMethodLength);
  } else {
    // Prepare for no such method. The code for invoking noSuchMethod is
    // located at the delta specified in the bytecode argument.
    state.Push(receiver);

    // These 3 arguments are passed to
    //     lib/core/core_patch.dart:Object._noSuchMethod()
    //
    // The number of arguments must be kept in sync with
    //     pkg/fletchc/lib/src/fletch_backend.dart:
    //       FletchBackend.codegenExternalNoSuchMethodTrampoline
    state.Push(receiver);
    state.Push(clazz);
    state.Push(selector_smi);
    state.Advance(state.ReadByte(1));
  }

  state.SaveState();
}

void HandleInvokeSelector(Process* process) {
  State state(process);

  Object* receiver = state.Pop();
  Smi* selector_smi = Smi::cast(state.Pop());
  int selector = selector_smi->value();
  int arity = Selector::ArityField::decode(selector);
  state.SetLocal(arity, receiver);
  state.PushFrameDescriptor(kInvokeSelectorLength);

  Class* clazz = receiver->IsSmi()
      ? state.program()->smi_class()
      : HeapObject::cast(receiver)->get_class();
  Function* target = clazz->LookupMethod(selector);
  if (target == NULL) {
    static const Names::Id name = Names::kNoSuchMethodTrampoline;
    target = clazz->LookupMethod(Selector::Encode(name, Selector::METHOD, 0));
  }
  state.Goto(target->bytecode_address_for(0));

  state.SaveState();
}

int HandleAtBytecode(Process* process, uint8* bcp, Object** sp) {
  // TODO(ajohnsen): Support validate stack.
  DebugInfo* debug_info = process->debug_info();
  if (debug_info != NULL) {
    // If we already are at the breakpoint, just clear it (to support stepping).
    if (debug_info->is_at_breakpoint()) {
      debug_info->ClearBreakpoint();
    } else if (debug_info->ShouldBreak(bcp, sp)) {
      return Interpreter::kBreakPoint;
    }
  }
  return Interpreter::kReady;
}

}  // namespace fletch
