// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_RELOCATOR_H_
#define SRC_VM_PROGRAM_RELOCATOR_H_

#include "src/vm/intrinsics.h"
#include "src/vm/program.h"
#include "src/vm/native_interpreter.h"

namespace dartino {

class ProgramHeapRelocator {
 public:
  ProgramHeapRelocator(
      Program* program, uint8* target, uword baseaddress,
      IntrinsicsTable* table = IntrinsicsTable::GetDefault(),
      void* method_entry = reinterpret_cast<void*>(InterpreterMethodEntry))
      : program_(program),
        target_(target),
        baseaddress_(baseaddress),
        table_(table),
        method_entry_(method_entry) {}

  int Relocate();

 private:
  Program* program_;
  uint8* target_;
  uword baseaddress_;
  IntrinsicsTable* table_;
  void* method_entry_;
};

}  // namespace dartino

#endif  // SRC_VM_PROGRAM_RELOCATOR_H_
