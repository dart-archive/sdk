// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_INFO_BLOCK_H_
#define SRC_VM_PROGRAM_INFO_BLOCK_H_

#include "src/vm/program.h"

namespace dartino {
class ProgramInfoBlock {
 public:
  ProgramInfoBlock();

  void PopulateFromProgram(Program* program);
  void WriteToProgram(Program* program);

  intptr_t magic() { return magic_; }

  Object** roots() { return &entry_; }

  void* end_of_roots() { return &end_; }

  static bool MightBeProgramInfoBlock(ProgramInfoBlock* block) {
    return block->magic_ == kProgramInfoMagic;
  }

 private:
  static const int kProgramInfoMagic = 0x96064EA9;

  intptr_t magic_;
  // This has to remain in sync with all the roots that are traversed by
  // IterateRoots in Program. Also, the type does not really matter as long
  // as it also is a pointer type and they won't be used in order (as in
  // their names are meaningless).
  Object* entry_;
#define ROOT_DECLARATION(type, name, CamelName) type* name##_;
  ROOTS_DO(ROOT_DECLARATION)
#undef ROOT_DECLARATION
  void* end_[0];
};

}  // namespace dartino
#endif  // SRC_VM_PROGRAM_INFO_BLOCK_H_
