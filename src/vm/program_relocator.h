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
  ProgramHeapRelocator(Program* program, uword baseaddress,
                       IntrinsicsTable* table = IntrinsicsTable::GetDefault())
      : program_(program),
        baseaddress_(baseaddress),
        table_(table) {}

  List<uint8> Relocate();

 private:
  Program* program_;
  uword baseaddress_;
  IntrinsicsTable* table_;
};

}  // namespace fletch

#endif  // SRC_VM_PROGRAM_RELOCATOR_H_
