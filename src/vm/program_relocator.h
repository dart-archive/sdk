// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_RELOCATOR_H_
#define SRC_VM_PROGRAM_RELOCATOR_H_

#include "src/vm/intrinsics.h"
#include "src/vm/program.h"

namespace fletch {

class ProgramHeapRelocator {
 public:
  ProgramHeapRelocator(Program* program, uint8* target, uword baseaddress,
                       IntrinsicsTable* table = IntrinsicsTable::GetDefault())
      : program_(program),
        target_(target),
        baseaddress_(baseaddress),
        table_(table) {}

  int Relocate();

 private:
  Program* program_;
  uint8* target_;
  uword baseaddress_;
  IntrinsicsTable* table_;
};

}  // namespace fletch

#endif  // SRC_VM_PROGRAM_RELOCATOR_H_
