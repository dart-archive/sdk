// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PROGRAM_GROUPS_H_
#define SRC_VM_PROGRAM_GROUPS_H_

#include "src/shared/globals.h"
#include "src/vm/program.h"

namespace dartino {

typedef uword ProgramGroup;

class ProgramGroups {
 public:
  static const int kNumberOfGroups = 5;

  ProgramGroups();
  ~ProgramGroups();

  ProgramGroup Create(const char* name);
  void Delete(ProgramGroup group);
  void AddProgram(ProgramGroup group, Program* program);
  void RemoveProgram(ProgramGroup group, Program* program);
  bool ContainsProgram(ProgramGroup group, Program* program);
  bool IsValidGroup(ProgramGroup group);

 private:
  char const* group_names_[kNumberOfGroups];
  uword used_group_mask_;
};

}  // namespace dartino

#endif  // SRC_VM_PROGRAM_GROUPS_H_
