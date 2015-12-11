// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_CODEGEN_H_
#define SRC_VM_CODEGEN_H_

#include "src/vm/assembler.h"
#include "src/vm/program.h"

namespace fletch {

class Codegen {
 public:
  Codegen(Program* program, Function* function, Assembler* assembler)
      : program_(program),
        function_(function),
        assembler_(assembler) {
  }

  void Generate();

 private:
  Program* const program_;
  Function* const function_;
  Assembler* const assembler_;

  Program* program() const { return program_; }
  Assembler* assembler() const { return assembler_; }

  void DoEntry();

  void DoLoadLocal(int index);
  void DoStoreLocal(int index);

  void DoLoadProgramRoot(int offset);
  void DoLoadProgramConstant(int index);

  void DoLoadInteger(int value);

  void DoInvokeMethod(int arity, int offset);

  void DoDrop(int n);

  void DoReturn();
};

}  // namespace fletch

#endif  // SRC_VM_CODEGEN_H_
