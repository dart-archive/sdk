// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_CODEGEN_H_
#define SRC_VM_CODEGEN_H_

#include "src/vm/assembler.h"
#include "src/vm/program.h"

#include "src/shared/natives.h"

namespace fletch {

class Codegen {
 public:
  Codegen(Program* program, Assembler* assembler)
      : program_(program),
        function_(NULL),
        assembler_(assembler),
        add_offset_(-1),
        sub_offset_(-1),
        eq_offset_(-1),
        ge_offset_(-1),
        gt_offset_(-1),
        le_offset_(-1),
        lt_offset_(-1),
        cc_(kMaterialized) {
  }

  void Generate(Function* function);

  void GenerateHelpers();

  int UpdateAddOffset(int original) {
    return add_offset_ >= 0 ? add_offset_ : original;
  }

  // The resume address should be in ECX.
  void DoSaveState();
  void DoRestoreState();

 private:
  static const Condition kMaterialized = static_cast<Condition>(-1);

  Program* const program_;
  Function* function_;
  Assembler* const assembler_;

  int add_offset_;
  int sub_offset_;
  int eq_offset_;
  int ge_offset_;
  int gt_offset_;
  int le_offset_;
  int lt_offset_;

  Condition cc_;

  enum BranchCondition {
    BRANCH_ALWAYS,
    BRANCH_IF_TRUE,
    BRANCH_IF_FALSE,
  };

  Program* program() const { return program_; }
  Assembler* assembler() const { return assembler_; }

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

  void DoInvokeMethod(int arity, int offset);
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

  void DoReturn();

  void DoStackOverflowCheck(int size);

  void DoIntrinsicGetField(int field);
  void DoIntrinsicSetField(int field);
  void DoIntrinsicListLength();
  void DoIntrinsicListIndexGet();
  void DoIntrinsicListIndexSet();

  void Materialize();
};

}  // namespace fletch

#endif  // SRC_VM_CODEGEN_H_
