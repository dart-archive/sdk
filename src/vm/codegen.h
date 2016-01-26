// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_CODEGEN_H_
#define SRC_VM_CODEGEN_H_

#include "src/vm/assembler.h"
#include "src/vm/program.h"
#include "src/vm/vector.h"

#include "src/shared/natives.h"

namespace fletch {

const Smi* const kInvalidSmi = reinterpret_cast<Smi*>(1);

class Slot {
 public:
  enum SlotKind {
    kUnknownSlot,
    kThisSlot,
    kConditionSlot,
    kRegisterSlot,
    kThisRegisterSlot,
    kSmiSlot,
  };

  Slot(Condition condition)
      : kind_(kConditionSlot),
        condition_(condition),
        smi_(kInvalidSmi) {
  }

  Slot(Smi* smi)
      : kind_(kSmiSlot),
        condition_(kInvalidCondition),
        smi_(smi) {
  }

  static Slot Unknown() { return Slot(kUnknownSlot); }
  static Slot This() { return Slot(kThisSlot); }
  static Slot Register() { return Slot(kRegisterSlot); }
  static Slot ThisRegister() { return Slot(kThisRegisterSlot); }

  bool IsUnknown() const { return kind_ == kUnknownSlot; }
  bool IsThis() const {
    return kind_ == kThisSlot || kind_ == kThisRegisterSlot;
  }
  bool IsCondition() const { return kind_ == kConditionSlot; }
  bool IsRegister() const {
    return kind_ == kRegisterSlot || kind_ == kThisRegisterSlot;
  }

  bool IsMaterialized() const {
    return kind_ == kUnknownSlot || kind_ == kThisSlot;
  }

  Condition condition() const {
    assert(condition_ != kInvalidCondition);
    return condition_;
  }

  SlotKind kind() const { return kind_; }

 private:
  Slot(SlotKind kind)
      : kind_(kind),
        condition_(kInvalidCondition),
        smi_(kInvalidSmi) {
  }

  static const Condition kInvalidCondition = static_cast<Condition>(-1);

  SlotKind kind_;
  Condition condition_;
  const Smi* smi_;
};

class Codegen;
class BasicBlock {
 public:

  BasicBlock(Codegen* codegen)
      : codegen_(codegen) {
  }

  void Clear() {
    stack_.Clear();
  }

  void MaterializeAndClear() {
    Materialize();
    Clear();
  }

  void Push(Slot slot) {
    Materialize();
    stack_.PushBack(slot);
  }

  void SetTop(Slot slot) {
    Drop(1);
    stack_.PushBack(slot);
  }

  Slot Pop() {
    if (stack_.IsEmpty()) return Slot::Unknown();
    return stack_.PopBack();
  }

  Slot Top() {
    if (stack_.IsEmpty()) return Slot::Unknown();
    return stack_.Back();
  }

  void Drop(int count) {
    for (int i = 0; i < count; i++) {
      if (stack_.IsEmpty()) return;
      stack_.PopBack();
    }
  }

  Slot GetAtOffset(size_t offset) {
    if (offset >= stack_.size()) return Slot::Unknown();
    return stack_[stack_.size() - (offset + 1)];
  }

  void SetAtOffset(size_t offset, Slot slot) {
    if (offset >= stack_.size()) return;
    stack_[stack_.size() - (offset + 1)] = slot;
  }

  bool IsTopCondition() {
    if (stack_.IsEmpty()) return false;
    return stack_.Back().IsCondition();
  }

  bool IsTopRegister() {
    if (stack_.IsEmpty()) return false;
    return stack_.Back().IsRegister();
  }

  bool IsMaterialized() {
    if (stack_.IsEmpty()) return false;
    return stack_.Back().IsUnknown();
  }

  void MaterializeKeepRegister() {
    if (IsTopRegister()) return;
    Materialize();
  }

  void ConditionToRegister();

  void Materialize();

  void Print() {
    printf("// basic_block: [");
    for (size_t i = 0; i < stack_.size(); i++) {
      if (i != 0) printf(", ");
      switch (stack_[i].kind()) {
        case Slot::kUnknownSlot: printf("unknown"); break;
        case Slot::kThisSlot: printf("this"); break;
        case Slot::kConditionSlot: printf("condition"); break;
        case Slot::kRegisterSlot: printf("register"); break;
        case Slot::kThisRegisterSlot: printf("this-register"); break;
        case Slot::kSmiSlot: printf("smi"); break;
      }
    }
    printf("]\n");
  }

 private:
  Program* program() const;
  Assembler* assembler() const;

  Codegen* const codegen_;
  Vector<Slot> stack_;
};

class Codegen {
 public:
  Codegen(Program* program,
          Assembler* assembler,
          HashMap<Function*, Class*>* function_owners)
      : program_(program),
        assembler_(assembler),
        function_owners_(function_owners),
        function_(NULL),
        basic_block_(this),
        add_offset_(-1),
        sub_offset_(-1),
        eq_offset_(-1),
        ge_offset_(-1),
        gt_offset_(-1),
        le_offset_(-1),
        lt_offset_(-1) {
  }

  void Generate(Function* function);

  void GenerateHelpers();

  int UpdateAddOffset(int original) {
    return add_offset_ >= 0 ? add_offset_ : original;
  }

  // The resume address should be in ECX.
  void DoSaveState();
  void DoRestoreState();

  Program* program() const { return program_; }
  Assembler* assembler() const { return assembler_; }

 private:
  Program* const program_;
  Assembler* const assembler_;
  HashMap<Function*, Class*>* const function_owners_;

  Function* function_;
  BasicBlock basic_block_;

  int add_offset_;
  int sub_offset_;
  int eq_offset_;
  int ge_offset_;
  int gt_offset_;
  int le_offset_;
  int lt_offset_;

  enum BranchCondition {
    BRANCH_ALWAYS,
    BRANCH_IF_TRUE,
    BRANCH_IF_FALSE,
  };

  void DoEntry();

  void DoSetupFrame();

  void DoLoadLocal(int index);
  void DoLoadField(int index);
  void DoLoadStatic(int index);
  void DoLoadStaticInit(int index);

  void DoStoreLocal(int index);
  void DoStoreField(int index);
  void DoStoreStatic(int index);

  void DoLoadProgramRoot(int offset);

  void DoLoadConstant(int bci, int offset);
  void DoLoadInteger(int value);

  void DoBranch(BranchCondition condition, int from, int to);

  void DoInvokeMethod(Class* klass, int arity, int offset);
  void DoInvokeStatic(int bci, int offset, Function* target);

  void DoInvokeTest(int offset);

  void DoInvokeAdd();
  void DoInvokeSub();

  void DoInvokeCompare(Condition condition, const char* suffix);

  void DoInvokeNative(Native native, int arity);

  void DoAllocate(Class* klass);

  void DoNegate();
  void DoIdentical();
  void DoIdenticalNonNumeric();

  void DoProcessYield();

  void DoDrop(int n);
  void DoDropMaterialized(int n);

  void DoReturn();

  void DoThrow();

  void DoStackOverflowCheck(int size);

  void DoIntrinsicGetField(int field);
  void DoIntrinsicSetField(int field);
  void DoIntrinsicListLength();
  void DoIntrinsicListIndexGet();
  void DoIntrinsicListIndexSet();
};

}  // namespace fletch

#endif  // SRC_VM_CODEGEN_H_
