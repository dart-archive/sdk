// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_MIPS_H_
#define SRC_VM_ASSEMBLER_MIPS_H_

#ifndef SRC_VM_ASSEMBLER_H_
#error Do not include assembler_mips.h directly; use assembler.h instead.
#endif

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace dartino {

enum Register {
  ZR =  0,
  AT =  1,
  V0 =  2,
  V1 =  3,
  A0 =  4,
  A1 =  5,
  A2 =  6,
  A3 =  7,
  T0 =  8,
  T1 =  9,
  T2 = 10,
  T3 = 11,
  T4 = 12,
  T5 = 13,
  T6 = 14,
  T7 = 15,
  S0 = 16,
  S1 = 17,
  S2 = 18,
  S3 = 19,
  S4 = 20,
  S5 = 21,
  S6 = 22,
  S7 = 23,
  T8 = 24,
  T9 = 25,
  K0 = 26,  //  mips kernel reserved register. DO NOT USE.
  K1 = 27,  //  mips kernel reserved register. DO NOT USE.
  GP = 28,
  SP = 29,
  FP = 30,
  RA = 31,
};

enum ScaleFactor {
  TIMES_1 = 0,
  TIMES_2 = 1,
  TIMES_4 = 2,
  TIMES_WORD_SIZE = TIMES_4,
  TIMES_8 = 3
};
enum ShiftType { SLL, SRL, SLLV, SRLV, SRA, SRAV };

enum Condition {
  F    =  0,    // False
  T    =  1,    // True
  UN   =  2,    // Unordered
  OR   =  3,    // Ordered
  EQ   =  4,    // Equal
  NEQ  =  5,    // Not Equal
  UEQ  =  6,    // Unordered or Equal
  OLG  =  7,    // Ordered or Less than or Greater Than
  OLT  =  8,    // Ordered Less Than
  UGE  =  9,    // Unordered or Greater Than or Equal
  ULT  = 10,    // Unordered or Less Than
  OGE  = 11,    // Ordered Greater Than or Equal
  OLE  = 12,    // Ordered Less Than or Equal
  UGT  = 13,    // Unordered or Greater Than
  ULE  = 14,    // Unordered or Less Than or Equal
  OGT  = 15,    // Ordered Greater Than
  SF   = 16,    // Signaling False
  ST   = 17,    // Signaling True
  NGLE = 18,    // Not Greater Than or Less Than or Equal
  GLE  = 19,    // Greater Than, or Less Than or Equal
  SEQ  = 20,    // Signaling Equal
  SNE  = 21,    // Signaling Not Equal
  NGL  = 22,    // Not Greater Than or Less Than
  GL   = 23,    // Greater Than or Less Than
  LT   = 24,    // Less Than
  NLT  = 25,    // Not Less Than
  NGE  = 26,    // Not Greater Than
  GE   = 27,    // Greater Than or Equal
  LE   = 28,    // Less Than or Equal
  NLE  = 29,    // Not Less Than or Equal
  NGT  = 30,    // Not Greater Than
  GT   = 31,    // Greater Than
};

class Immediate {
 public:
  explicit Immediate(int32_t value) : value_(value) {}
  int32_t value() const { return value_; }

 private:
  const int32_t value_;
};

class Address {
 public:
  Address(Register base, int32_t offset)
      : base_(base), offset_(offset) {}

  Register base() const { return base_; }
  int32_t offset() const { return offset_; }

 private:
  const Register base_;
  const int32_t offset_;
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
  INSTRUCTION_3(addi, "addi %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(addu, "addu %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(addiu, "addiu %r, %r, %i", Register, Register,
                const Immediate&);

  INSTRUCTION_3(andi, "andi %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(and_, "and %r, %r, %r", Register, Register, Register);

  INSTRUCTION_0(break_, "break");

  INSTRUCTION_1(b, "b %s", const char*);
  INSTRUCTION_1(b, "b %l", Label*);
  INSTRUCTION_2(b, "b%c %l", Condition, Label*);
  INSTRUCTION_4(b, "b%c %r, %r, %l", Condition, Register, Register, Label*);
  INSTRUCTION_4(b, "b%c %r, %r, %s", Condition, Register, Register,
                const char*);

  INSTRUCTION_1(jal, "jal %s", const char*);
  INSTRUCTION_1(jalr, "jalr %r", Register);
  INSTRUCTION_1(jr, "jr %r", Register);

  INSTRUCTION_2(la, "la %r, %s", Register, const char*);
  INSTRUCTION_2(la, "la %r, %l", Register, Label*);
  INSTRUCTION_2(li, "li %r, %i", Register, const Immediate&);
  INSTRUCTION_2(lui, "lui %r, %i", Register, const Immediate&);

  INSTRUCTION_2(lb, "lb %r, %a", Register, const Address&);
  INSTRUCTION_2(lbu, "lbu %r, %a", Register, const Address&);
  INSTRUCTION_2(lw, "lw %r, %a", Register, const Address&);
  INSTRUCTION_2(lw, "lw %r, %s", Register, const char*);

  INSTRUCTION_2(move, "move %r, %r", Register, Register);
  INSTRUCTION_2(mult, "mult %r, %r", Register, Register);

  INSTRUCTION_1(mfhi, "mfhi %r", Register);
  INSTRUCTION_1(mflo, "mflo %r", Register);

  INSTRUCTION_0(nop, "nop");
  INSTRUCTION_2(not_, "nor %r, %r, $0", Register, Register);

  INSTRUCTION_3(or_, "or %r, %r, %r", Register, Register, Register);

  INSTRUCTION_3(sll, "sll %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(sllv, "sllv %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(sra, "sra %r, %r, %i", Register, Register, const Immediate&);
  INSTRUCTION_3(srav, "srav %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(srl, "srl %r, %r, %i", Register, Register, const Immediate&);

  INSTRUCTION_3(slt, "slt %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(sltu, "sltu %r, %r, %r", Register, Register, Register);


  INSTRUCTION_3(sub, "sub %r, %r, %r", Register, Register, Register);
  INSTRUCTION_3(subi, "addi %r, %r, -%i", Register, Register, const Immediate&);
  INSTRUCTION_3(subu, "subu %r, %r, %r", Register, Register, Register);

  INSTRUCTION_0(syscall, "syscall");

  INSTRUCTION_2(sb, "sb %r, %a", Register, const Address&);
  INSTRUCTION_2(sw, "sw %r, %a", Register, const Address&);

  INSTRUCTION_3(xor_, "xor %r, %r, %r", Register, Register, Register);


  // Align what follows to a 2^power address.
  void AlignToPowerOfTwo(int power);

  void Bind(const char* prefix, const char* name);
  void Bind(Label* label);

  void DefineLong(const char* name);

  void SwitchToText();

  void BindWithPowerOfTwoAlignment(const char* name, int power);
  void SwitchToData();

  const char* LabelPrefix();

 private:
  void Print(const char* format, ...);
  void PrintAddress(const Address* address);

  Condition Wrap(Condition condition) { return condition; }
  Register Wrap(Register reg) { return reg; }
  const char* Wrap(const char* label) { return label; }
  Label* Wrap(Label* label) { return label; }
  const Immediate* Wrap(const Immediate& immediate) { return &immediate; }
  const Address* Wrap(const Address& address) { return &address; }
};

#undef INSTRUCTION_0
#undef INSTRUCTION_1
#undef INSTRUCTION_2
#undef INSTRUCTION_3
#undef INSTRUCTION_4

}  // namespace dartino

#endif  // SRC_VM_ASSEMBLER_MIPS_H_
