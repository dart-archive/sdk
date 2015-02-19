// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_ARM_H_
#define SRC_VM_ASSEMBLER_ARM_H_

#ifndef SRC_VM_ASSEMBLER_H_
#error Do not include assembler_x64.h directly; use assembler.h instead.
#endif

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace fletch {

enum Register {
  R0  =  0,
  R1  =  1,
  R2  =  2,
  R3  =  3,
  R4  =  4,
  R5  =  5,
  R6  =  6,
  R7  =  7,
  R8  =  8,
  R9  =  9,
  R10 = 10,
  R11 = 11,
  R12 = 12,
  R13 = 13,
  R14 = 14,
  R15 = 15,
  FP  = 11,
  IP  = 12,
  SP  = 13,
  LR  = 14,
  PC  = 15,
};

class Immediate {
 public:
  explicit Immediate(int32 value) : value_(value) { }
  int32 value() const { return value_; }

 private:
  const int32 value_;
};

class Label {
 public:
  Label() : position_(0) { }

  // Returns the position for bound and linked labels. Cannot be used
  // for unused labels.
  int position() const {
    ASSERT(!IsUnused());
    return IsBound() ? -position_ - 1 : position_ - 1;
  }

  bool IsBound() const { return position_ < 0; }
  bool IsUnused() const { return position_ == 0; }
  bool IsLinked() const { return position_ > 0; }

 private:
  int position_;

  void BindTo(int position) {
    position_ = -position - 1;
    ASSERT(IsBound());
  }

  void LinkTo(int position) {
    position_ = position + 1;
    ASSERT(IsLinked());
  }

  friend class Assembler;
};

#define INSTRUCTION_0(name, format) \
  void name() { Print(format); }

#define INSTRUCTION_1(name, format, t0) \
  void name(t0 a0) { Print(format, Wrap(a0)); }

#define INSTRUCTION_2(name, format, t0, t1) \
  void name(t0 a0, t1 a1) { Print(format, Wrap(a0), Wrap(a1)); }

class Assembler {
 public:
  INSTRUCTION_2(mov, "mov %r, %r", Register, Register);
  INSTRUCTION_2(mov, "mov %r, %i", Register, const Immediate&);
  INSTRUCTION_0(bkpt, "bkpt");

  void Align(int alignment);

  void Bind(const char* name);
  void Bind(Label* label);

  void DefineLong(const char* name);

 private:
  void Print(const char* format, ...);

  static int NewLabelPosition();

  Register Wrap(Register reg) { return reg; }
  const Immediate* Wrap(const Immediate& immediate) { return &immediate; }
};

#undef INSTRUCTION_0
#undef INSTRUCTION_1
#undef INSTRUCTION_2

}  // namespace fletch

#endif  // SRC_VM_ASSEMBLER_ARM_H_
