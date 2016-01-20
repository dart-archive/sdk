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
  Codegen(Program* program, Function* function, Assembler* assembler)
      : program_(program),
        function_(function),
        assembler_(assembler),
        add_offset_(-1) {
  }

  void Generate();

  int UpdateAddOffset(int original) {
    return add_offset_ >= 0 ? add_offset_ : original;
  }

  // The resume address should be in ECX.
  void DoSaveState();
  void DoRestoreState();

 private:
  Program* const program_;
  Function* const function_;
  Assembler* const assembler_;

  int add_offset_;

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
  void DoInvokeLt();

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
};

}  // namespace fletch

#endif  // SRC_VM_CODEGEN_H_
