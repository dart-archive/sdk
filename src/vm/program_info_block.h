// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_INFO_BLOCK_H_
#define SRC_VM_PROGRAM_INFO_BLOCK_H_

#include "src/vm/program.h"

namespace fletch {
class ProgramInfoBlock {
 public:
  ProgramInfoBlock();

  void PopulateFromProgram(Program* program);
  void WriteToProgram(Program* program);

  Object** roots() { return &entry_; }

  void* end_of_roots() { return &main_arity_; }

  void set_main_arity(int arity) { main_arity_ = arity; }
  int main_arity() { return main_arity_; }

 private:
  // This has to remain in sync with all the roots that are traversed by
  // IterateRoots in Program. Also, the type does not really matter as long
  // as it also is a pointer type and they won't be used in order (as in
  // their names are meaningless).
  Object* entry_;
#define ROOT_DECLARATION(type, name, CamelName) type* name##_;
  ROOTS_DO(ROOT_DECLARATION)
#undef ROOT_DECLARATION
  // We also store the arity of main. This field is also used as a marker
  // of the end of the roots data structure.
  intptr_t main_arity_;
};

}  // namespace fletch
#endif  // SRC_VM_PROGRAM_INFO_BLOCK_H_
