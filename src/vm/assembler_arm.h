// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_ARM_H_
#define SRC_VM_ASSEMBLER_ARM_H_

#ifndef SRC_VM_ASSEMBLER_H_
#error Do not include assembler_arm.h directly; use assembler.h instead.
#endif

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace dartino {

enum Register {
  R0 = 0,
  R1 = 1,
  R2 = 2,
  R3 = 3,
  R4 = 4,
  R5 = 5,
  R6 = 6,
  R7 = 7,
  R8 = 8,
  R9 = 9,
  R10 = 10,
  R11 = 11,
  R12 = 12,
  R13 = 13,
  R14 = 14,
  R15 = 15,
  FP = 11,
  IP = 12,
  SP = 13,
  LR = 14,
  PC = 15,
};

enum ScaleFactor {
  TIMES_1 = 0,
  TIMES_2 = 1,
  TIMES_4 = 2,
  TIMES_WORD_SIZE = TIMES_4,
  TIMES_8 = 3
};

enum ShiftType { LSL, ASR, LSR };

enum Condition {
  EQ = 0,   // equal
  NE = 1,   // not equal
  CS = 2,   // carry set/unsigned higher or same
  CC = 3,   // carry clear/unsigned lower
  MI = 4,   // minus/negative
  PL = 5,   // plus/positive or zero
  VS = 6,   // overflow
  VC = 7,   // no overflow
  HI = 8,   // unsigned higher
  LS = 9,   // unsigned lower or same
  GE = 10,  // signed greater than or equal
  LT = 11,  // signed less than
  GT = 12,  // signed greater than
  LE = 13,  // signed less than or equal
  AL = 14,  // always (unconditional)
};

enum WriteBack {
  WRITE_BACK_DISABLED = 0,
  WRITE_BACK = 1,
};

typedef uint32_t RegisterList;

class Immediate {
 public:
  explicit Immediate(int32_t value) : value_(value) {}
  int32_t value() const { return value_; }

 private:
  const int32_t value_;
};

class Operand {
 public:
  Operand(Register reg, ScaleFactor scale)
      : reg_(reg), shift_type_(LSL), shift_amount_(scale) {}

  Operand(const Operand& other)
      : reg_(other.reg()),
        shift_type_(other.shift_type()),
        shift_amount_(other.shift_amount()) {}

  Operand(Register reg, ShiftType shift_type, int shift_amount)
      : reg_(reg), shift_type_(shift_type), shift_amount_(shift_amount) {}

  Register reg() const { return reg_; }
  ShiftType shift_type() const { return shift_type_; }
  int shift_amount() const { return shift_amount_; }

 private:
  const Register reg_;
  const ShiftType shift_type_;
  const int shift_amount_;
};

class Address {
 public:
  enum Kind { IMMEDIATE, OPERAND };

  Address(Register base, int32_t offset)
      : base_(base), offset_(offset), operand_(R0, TIMES_1), kind_(IMMEDIATE) {}

  Address(Register base, const Operand& operand)
      : base_(base), offset_(0), operand_(operand), kind_(OPERAND) {}

  Register base() const { return base_; }
  int32_t offset() const { return offset_; }
  const Operand* operand() const { return &operand_; }
  Kind kind() const { return kind_; }

 private:
  const Register base_;
  const int32_t offset_;
  const Operand operand_;
  const Kind kind_;
};

class Label {
 public:
  Label() : position_(-1) {}

  // Returns the position for a label. Positions are assigned on first use.
  int position() {
    if (position_ == -1) position_ = position_counter_++;
    return position_;
  }

 private:
  int position_;
  static int position_counter_;
};

#define INSTRUCTION_0(name, format) \
  void name() { Print(format); }

#define INSTRUCTION_1(name, format, t0) \
  void name(t0 a0) { Print(format, Wrap(a0)); }

#define INSTRUCTION_2(name, format, t0, t1) \
  void name(t0 a0, t1 a1) { Print(format, Wrap(a0), Wrap(a1)); }

#define INSTRUCTION_3(name, format, t0, t1, t2)  \
  void name(t0 a0, t1 a1, t2 a2) {               \
    Print(format, Wrap(a0), Wrap(a1), Wrap(a2)); \
  }

#define INSTRUCTION_4(name, format, t0, t1, t2, t3)        \
  void name(t0 a0, t1 a1, t2 a2, t3 a3) {                  \
    Print(format, Wrap(a0), Wrap(a1), Wrap(a2), Wrap(a3)); \
  }

class Assembler {
 public:
  INSTRUCTION_3(add, "add %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(add, "add %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(add, "add %r, %r, %o", Register, Register, const Operand&);
  INSTRUCTION_3(adds, "adds %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(adds, "adds %r, %r, %i", Register, Register, const Immediate&);

  INSTRUCTION_3(and_, "and %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(and_, "and %r, %r, %r", Register, Register, Register);

  INSTRUCTION_3(asr, "asr %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(asr, "asr %r, %r, %r", Register, Register, Register);

  INSTRUCTION_1(b, "b %s", const char*);
  INSTRUCTION_2(b, "b%c %s", Condition, const char*);
  INSTRUCTION_1(b, "b %l", Label*);
  INSTRUCTION_2(b, "b%c %l", Condition, Label*);

  INSTRUCTION_3(bic, "bic %r, %r, %i", Register, Register, const Immediate&);

  INSTRUCTION_0(bkpt, "bkpt");

  INSTRUCTION_1(bl, "bl %s", const char*);
  INSTRUCTION_1(blx, "blx %r", Register);
  INSTRUCTION_1(bx, "bx %r", Register);

  INSTRUCTION_2(cmp, "cmp %r, %r", Register, Register);
  INSTRUCTION_2(cmp, "cmp %r, %i", Register, const Immediate&);
  INSTRUCTION_2(cmp, "cmp %r, %o", Register, const Operand&);

  INSTRUCTION_3(eor, "eor %r, %r, %r", Register, Register, Register);

  INSTRUCTION_2(ldr, "ldr %r, %a", Register, const Address&);
  INSTRUCTION_2(ldr, "ldr %r, =%s", Register, const char*);
  INSTRUCTION_2(ldr, "ldr %r, =%l", Register, Label*);
  INSTRUCTION_3(ldr, "ldr %r, [%r], %i", Register, Register, const Immediate&);
  INSTRUCTION_2(ldrb, "ldrb %r, %a", Register, const Address&);
  INSTRUCTION_3(ldrb, "ldrb %r, %a%W", Register, const Address&, WriteBack);

  INSTRUCTION_3(lsl, "lsl %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(lsl, "lsl %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(lsr, "lsr %r, %r, %i", Register, Register, const Immediate&);

  INSTRUCTION_2(mov, "mov %r, %r", Register, Register);
  INSTRUCTION_2(mov, "mov %r, %i", Register, const Immediate&);
  INSTRUCTION_3(mov, "mov%c %r, %i", Condition, Register, const Immediate&);

  INSTRUCTION_2(mvn, "mvn %r, %r", Register, Register);
  INSTRUCTION_2(mvn, "mvn %r, %i", Register, const Immediate&);

  INSTRUCTION_2(neg, "neg %r, %r", Register, Register);

  INSTRUCTION_0(nop, "nop");

  INSTRUCTION_3(orr, "orr %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(orr, "orr %r, %r, %r", Register, Register, Register);

  INSTRUCTION_1(pop, "pop { %r }", Register);
  INSTRUCTION_1(pop, "pop { %R }", RegisterList);

  INSTRUCTION_1(push, "push { %r }", Register);
  INSTRUCTION_1(push, "push { %R }", RegisterList);

  INSTRUCTION_4(smull, "smull %r, %r, %r, %r", Register, Register, Register,
                Register);

  INSTRUCTION_2(str, "str %r, %a", Register, const Address&);
  INSTRUCTION_3(str, "str %r, %a%W", Register, const Address&, WriteBack);
  INSTRUCTION_3(str, "str %r, [%r], %i", Register, Register, const Immediate&);
  INSTRUCTION_3(str, "str%c %r, %a", Condition, Register, const Address&);

  INSTRUCTION_2(strb, "strb %r, %a", Register, const Address&);

  INSTRUCTION_3(sub, "sub %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(sub, "sub %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(sub, "sub %r, %r, %o", Register, Register, const Operand&);
  INSTRUCTION_3(subs, "subs %r, %r, %r", Register, Register, Register);

  INSTRUCTION_2(tst, "tst %r, %i", Register, const Immediate&);
  INSTRUCTION_2(tst, "tst %r, %r", Register, Register);

  void LoadInt(Register reg, int value);

  void BindWithPowerOfTwoAlignment(const char* name, int power);
  void Bind(const char* prefix, const char* name);
  void Bind(Label* label);

  void DefineLong(const char* name);

  void SwitchToText();
  void SwitchToData();

  // Align what follows to a 2^power address.
  void AlignToPowerOfTwo(int power);

  void GenerateConstantPool();

  const char* LabelPrefix();

 private:
  // Do not use this one directly. Use LoadInt instead.
  INSTRUCTION_2(ldr, "ldr %r, %I", Register, const Immediate&);

  void Print(const char* format, ...);
  void PrintAddress(const Address* address);
  void PrintOperand(const Operand* operand);

  Condition Wrap(Condition condition) { return condition; }
  Register Wrap(Register reg) { return reg; }
  WriteBack Wrap(WriteBack wb) { return wb; }
  RegisterList Wrap(RegisterList regs) { return regs; }
  const char* Wrap(const char* label) { return label; }
  Label* Wrap(Label* label) { return label; }
  const Immediate* Wrap(const Immediate& immediate) { return &immediate; }
  const Address* Wrap(const Address& address) { return &address; }
  const Operand* Wrap(const Operand& operand) { return &operand; }
};

#undef INSTRUCTION_0
#undef INSTRUCTION_1
#undef INSTRUCTION_2

}  // namespace dartino

#endif  // SRC_VM_ASSEMBLER_ARM_H_
