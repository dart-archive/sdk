// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/program_groups.h"

namespace dartino {

ProgramGroups::ProgramGroups() : used_group_mask_(0) {}
ProgramGroups::~ProgramGroups() {
  ASSERT(used_group_mask_ == 0);
}

ProgramGroup ProgramGroups::Create(const char* name) {
  for (uword bit = 0; bit < kNumberOfGroups; bit++) {
    if ((used_group_mask_ >> bit) != 1) {
      used_group_mask_ |= 1 << bit;
      group_names_[bit] = name;
      return bit + 1;
    }
  }
  return 0;
}

void ProgramGroups::Delete(ProgramGroup group) {
  ASSERT(group != 0);
  ASSERT(IsValidGroup(group));
  uword bit = group - 1;
  used_group_mask_ &= ~(1 << bit);
  group_names_[bit] = NULL;
}

void ProgramGroups::AddProgram(ProgramGroup group, Program* program) {
  ASSERT(IsValidGroup(group));
  uword bit = group - 1;
  program->group_mask_ |= 1 << bit;
}

void ProgramGroups::RemoveProgram(ProgramGroup group, Program* program) {
  ASSERT(IsValidGroup(group));
  uword bit = group - 1;
  program->group_mask_ &= ~(1 << bit);
}

bool ProgramGroups::ContainsProgram(ProgramGroup group, Program* program) {
  ASSERT(IsValidGroup(group));
  uword bit = group - 1;
  return (program->group_mask_ & (1 << bit)) != 0;
}

bool ProgramGroups::IsValidGroup(ProgramGroup group) {
  if (group == 0) return false;
  uword bit = group - 1;
  return (used_group_mask_ & (1 << bit)) != 0;
}

}  // namespace dartino
