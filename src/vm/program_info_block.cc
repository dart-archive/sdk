// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/program_info_block.h"

namespace dartino {

class PointerReadingVisitor : public PointerVisitor {
 public:
  explicit PointerReadingVisitor(ProgramInfoBlock* info)
      :
#ifdef DEBUG
        info_(info),
#endif
        target_(info->roots()) {
  }
  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      *(target_++) = *p;
    }
#ifdef DEBUG
    ASSERT(target_ <= info_->end_of_roots());
#endif
  }

 private:
#ifdef DEBUG
  ProgramInfoBlock* info_;
#endif
  Object** target_;
};

class PointerWritingVisitor : public PointerVisitor {
 public:
  explicit PointerWritingVisitor(ProgramInfoBlock* info)
      :
#ifdef DEBUG
        info_(info),
#endif
        target_(info->roots()) {
  }
  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      *p = *(target_++);
    }
#ifdef DEBUG
    ASSERT(target_ <= info_->end_of_roots());
#endif
  }

 private:
#ifdef DEBUG
  ProgramInfoBlock* info_;
#endif
  Object** target_;
};

ProgramInfoBlock::ProgramInfoBlock()
    : magic_(kProgramInfoMagic),
      entry_(NULL)
#define CONSTRUCTOR_NULL(type, name, CamelName) , name##_(NULL)
          ROOTS_DO(CONSTRUCTOR_NULL)
#undef CONSTRUCTOR_NULL
{
#define CONSTRUCTOR_USE(type, name, CamelName) USE(name##_);
  ROOTS_DO(CONSTRUCTOR_USE)
#undef CONSTRUCTOR_USE
}

void ProgramInfoBlock::PopulateFromProgram(Program* program) {
  // We set the magic here, too, as we might not use the constructor
  // to build an instance.
  magic_ = kProgramInfoMagic;
  snapshot_hash_ = program->snapshot_hash();
  ASSERT(program->session() == NULL);
  PointerReadingVisitor reader(this);
  program->IterateRoots(&reader);
}

void ProgramInfoBlock::WriteToProgram(Program* program) {
  ASSERT(program->session() == NULL);
  ASSERT(magic_ == kProgramInfoMagic);
  program->set_snapshot_hash(snapshot_hash_);
  PointerWritingVisitor writer(this);
  program->IterateRoots(&writer);
}

}  // namespace dartino
