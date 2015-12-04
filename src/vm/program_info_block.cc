// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/program_info_block.h"

namespace fletch {

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
    : entry_(NULL),
#define CONSTRUCTOR_NULL(type, name, CamelName) name##_(NULL),
      ROOTS_DO(CONSTRUCTOR_NULL)
#undef CONSTRUCTOR_NULL
          main_arity_(0) {
#define CONSTRUCTOR_USE(type, name, CamelName) USE(name##_);
  ROOTS_DO(CONSTRUCTOR_USE)
#undef CONSTRUCTOR_USE
}

void ProgramInfoBlock::PopulateFromProgram(Program* program) {
  ASSERT(program->session() == NULL);
  PointerReadingVisitor reader(this);
  program->IterateRoots(&reader);
  set_main_arity(program->main_arity());
}

void ProgramInfoBlock::WriteToProgram(Program* program) {
  ASSERT(program->session() == NULL);
  PointerWritingVisitor writer(this);
  program->IterateRoots(&writer);
  program->set_main_arity(main_arity());
}

}  // namespace fletch
