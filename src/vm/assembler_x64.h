// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_X64_H_
#define SRC_VM_ASSEMBLER_X64_H_

#ifndef SRC_VM_ASSEMBLER_H_
#error Do not include assembler_x64.h directly; use assembler.h instead.
#endif

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace dartino {

extern const char* kLocalLabelPrefix;

enum Register {
  RAX = 0,
  RCX = 1,
  RDX = 2,
  RBX = 3,
  RSP = 4,
  RBP = 5,
  RSI = 6,
  RDI = 7,
  R8 = 8,
  R9 = 9,
  R10 = 10,
  R11 = 11,
  R12 = 12,
  R13 = 13,
  R14 = 14,
  R15 = 15,
  RIP = 16,
  XMM0 = 17,
  XMM1 = 18,
  XMM2 = 19,
  XMM3 = 20,
  XMM4 = 21,
  XMM5 = 22,
  XMM6 = 23,
  XMM7 = 24,
  XMM8 = 25,
  XMM9 = 26,
  XMM10 = 27,
  XMM11 = 28,
  XMM12 = 29,
  XMM13 = 30,
  XMM14 = 31,
  XMM15 = 32
};

enum ScaleFactor {
  TIMES_1 = 0,
  TIMES_2 = 1,
  TIMES_4 = 2,
  TIMES_8 = 3,
  TIMES_WORD_SIZE = TIMES_8
};

enum Condition {
  OVERFLOW_ = 0,
  NO_OVERFLOW = 1,
  BELOW = 2,
  ABOVE_EQUAL = 3,
  EQUAL = 4,
  NOT_EQUAL = 5,
  BELOW_EQUAL = 6,
  ABOVE = 7,
  SIGN = 8,
  NOT_SIGN = 9,
  PARITY_EVEN = 10,
  PARITY_ODD = 11,
  LESS = 12,
  GREATER_EQUAL = 13,
  LESS_EQUAL = 14,
  GREATER = 15,

  ZERO = EQUAL,
  NOT_ZERO = NOT_EQUAL,
  NEGATIVE = SIGN,
  POSITIVE = NOT_SIGN
};

class Immediate {
 public:
  explicit Immediate(int64 value) : value_(value) {}

  int64 value() const { return value_; }

  bool is_int32() const { return Utils::IsInt32(value_); }

  bool is_int8() const { return Utils::IsInt8(value_); }

 private:
  const int64 value_;
};

class Operand {
 public:
  uint8 mod() const { return (EncodingAt(0) >> 6) & 3; }

  Register rm() const {
    int rm_rex = (rex_ & 1) << 3;
    return static_cast<Register>(rm_rex + (EncodingAt(0) & 7));
  }

  ScaleFactor scale() const {
    return static_cast<ScaleFactor>((EncodingAt(1) >> 6) & 3);
  }

  Register index() const {
    int index_rex = (rex_ & 2) << 2;
    return static_cast<Register>(index_rex + ((EncodingAt(1) >> 3) & 7));
  }

  Register base() const {
    int base_rex = (rex_ & 1) << 3;
    return static_cast<Register>(base_rex + (EncodingAt(1) & 7));
  }

  int8 disp8() const {
    ASSERT(length_ >= 2);
    return *reinterpret_cast<const int8*>(&encoding_[length_ - 1]);
  }

  int32 disp32() const {
    ASSERT(length_ >= 5);
    return *reinterpret_cast<const int32*>(&encoding_[length_ - 4]);
  }

 protected:
  Operand() : length_(0), rex_(0) {}

  void SetModRM(int mod, Register rm) {
    ASSERT((mod & ~3) == 0);
    if (rm > 7) rex_ |= 1;
    encoding_[0] = (mod << 6) | (rm & 7);
    length_ = 1;
  }

  void SetSIB(ScaleFactor scale, Register index, Register base) {
    ASSERT(length_ == 1);
    ASSERT((scale & ~3) == 0);
    if (base > 7) {
      ASSERT((rex_ & 1) == 0);  // Must not have REX.B already set.
      rex_ |= 1;
    }
    if (index > 7) rex_ |= 2;
    encoding_[1] = (scale << 6) | ((index & 7) << 3) | (base & 7);
    length_ = 2;
  }

  void SetDisp8(int8 disp) {
    ASSERT(length_ == 1 || length_ == 2);
    *reinterpret_cast<int8*>(&encoding_[length_++]) = disp;
  }

  void SetDisp32(int32 disp) {
    ASSERT(length_ == 1 || length_ == 2);
    *reinterpret_cast<int32*>(&encoding_[length_]) = disp;
    length_ += 4;
  }

 private:
  uint8 length_;
  uint8 rex_;
  uint8 encoding_[6];

  explicit Operand(Register reg) { SetModRM(3, reg); }

  // Get the operand encoding byte at the given index.
  uint8 EncodingAt(int index) const {
    ASSERT(index >= 0 && index < length_);
    return encoding_[index];
  }

  friend class Assembler;
};

class Address : public Operand {
 public:
  explicit Address(Register base, int32 disp = 0) {
    if (disp == 0 && base != RBP) {
      SetModRM(0, base);
      if (base == RSP) SetSIB(TIMES_1, RSP, base);
    } else if (Utils::IsInt8(disp)) {
      SetModRM(1, base);
      if (base == RSP) SetSIB(TIMES_1, RSP, base);
      SetDisp8(disp);
    } else {
      SetModRM(2, base);
      if (base == RSP) SetSIB(TIMES_1, RSP, base);
      SetDisp32(disp);
    }
  }

  Address(Register index, ScaleFactor scale, int32 disp = 0) {
    ASSERT(index != RSP);  // Illegal addressing mode.
    SetModRM(0, RSP);
    SetSIB(scale, index, RBP);
    SetDisp32(disp);
  }

  Address(Register base, Register index, ScaleFactor scale, int32 disp = 0) {
    ASSERT(index != RSP);  // Illegal addressing mode.
    if (disp == 0 && base != RBP) {
      SetModRM(0, RSP);
      SetSIB(scale, index, base);
    } else if (Utils::IsInt8(disp)) {
      SetModRM(1, RSP);
      SetSIB(scale, index, base);
      SetDisp8(disp);
    } else {
      SetModRM(2, RSP);
      SetSIB(scale, index, base);
      SetDisp32(disp);
    }
  }
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
  void name(t0 a0, t1 a1) { Print(format, Wrap(a1), Wrap(a0)); }

#define INSTRUCTION_3(name, format, t0, t1, t2) \
  void name(t0 a0, t1 a1, t2 a2) { \
    Print(format, Wrap(a2), Wrap(a1), Wrap(a0)); \
  }

class Assembler {
 public:
  INSTRUCTION_1(pushq, "pushq %rq", Register);
  INSTRUCTION_1(pushq, "pushq %a", const Address&);
  INSTRUCTION_1(pushq, "pushq %i", const Immediate&);

  INSTRUCTION_1(popq, "popq %rq", Register);
  INSTRUCTION_1(popq, "popq %a", const Address&);

  INSTRUCTION_1(negq, "negq %rq", Register);
  INSTRUCTION_1(notq, "notq %rq", Register);
  INSTRUCTION_1(imul, "imul %rq", Register);

  INSTRUCTION_1(call, "call *%rq", Register);

  INSTRUCTION_2(movl, "movl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(movl, "movl %a, %rl", Register, const Address&);
  INSTRUCTION_2(movl, "movl %rl, %a", const Address&, Register);

  INSTRUCTION_2(movq, "movq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(movq, "movq %rq, %rq", Register, Register);
  INSTRUCTION_2(movq, "movq %a, %rq", Register, const Address&);
  INSTRUCTION_2(movq, "movq %rq, %a", const Address&, Register);
  INSTRUCTION_2(movq, "movq %l, %a", const Address&, const Immediate&);
  INSTRUCTION_3(movq, "movq %m(%rq), %rq",
    Register, Register, const Immediate&);
  INSTRUCTION_3(movq, "movq %rq, %m(%rq)",
    Register, const Immediate&, Register);
  INSTRUCTION_3(movss, "movss %m(%rq), %rq",
    Register, Register, const Immediate&);
  INSTRUCTION_3(movss, "movss %rq, %m(%rq)",
    Register, const Immediate&, Register);
  INSTRUCTION_3(movsd, "movsd %m(%rq), %rq",
    Register, Register, const Immediate&);
  INSTRUCTION_3(movsd, "movsd %rq, %m(%rq)",
    Register, const Immediate&, Register);

  INSTRUCTION_2(movb, "movb %b, %a", const Address&, const Immediate&);

  INSTRUCTION_2(movzbq, "movzbq %a, %rq", Register, const Address&);

  INSTRUCTION_2(cmove, "cmove %rq, %rq", Register, Register);

  INSTRUCTION_2(leaq, "leaq %a, %rq", Register, const Address&);

  INSTRUCTION_1(call, "call *%a", const Address&);

  INSTRUCTION_1(jmp, "jmp *%rq", Register);

  INSTRUCTION_2(cmpl, "cmpl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(cmpl, "cmpl %rl, %rl", Register, Register);

  INSTRUCTION_2(cmpq, "cmpq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(cmpq, "cmpq %rq, %rq", Register, Register);
  INSTRUCTION_2(cmpq, "cmpq %a, %rq", Register, const Address&);

  INSTRUCTION_2(testl, "testl %rl, %rl", Register, Register);
  INSTRUCTION_2(testl, "testl %i, %rl", Register, const Immediate&);

  INSTRUCTION_2(testq, "testq %rq, %rq", Register, Register);
  INSTRUCTION_2(testq, "testq %i, %rq", Register, const Immediate&);

  INSTRUCTION_2(addl, "addl %rl, %rl", Register, Register);
  INSTRUCTION_2(addl, "addl %i, %a", const Address&, const Immediate&);

  INSTRUCTION_2(addq, "addq %rq, %rq", Register, Register);
  INSTRUCTION_2(addq, "addq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(addq, "addq %l, %a", const Address&, const Immediate&);
  INSTRUCTION_2(addq, "addq %a, %rq", Register, const Address&);

  INSTRUCTION_2(andq, "andq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(andq, "andq %rq, %rq", Register, Register);

  INSTRUCTION_2(orq, "orq %rq, %rq", Register, Register);

  INSTRUCTION_2(shrq, "shrq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(sarq, "sarq %l, %rq", Register, const Immediate&);
  INSTRUCTION_1(sarq_cl, "sarq %%cl, %rq", Register);

  INSTRUCTION_2(shll, "shll %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(shlq, "shlq %i, %rq", Register, const Immediate&);
  INSTRUCTION_1(shlq_cl, "shlq %%cl, %rq", Register);

  INSTRUCTION_2(subq, "subq %l, %rq", Register, const Immediate&);
  INSTRUCTION_2(subq, "subq %rq, %rq", Register, Register);

  INSTRUCTION_2(xorq, "xorq %rq, %rq", Register, Register);

  INSTRUCTION_0(ret, "ret");
  INSTRUCTION_0(nop, "nop");
  INSTRUCTION_0(int3, "int3");

  void movq(Register reg, Label* label);

  void j(Condition condition, Label* label);
  void j(Condition condition, const char* name);

  void jmp(Label* label);
  void jmp(const char* name);
  void jmp(const char* name, Register index, ScaleFactor scale,
           Register scratch);

  void call(const char* name);

  void SwitchToData();
  void SwitchToText();

  void Bind(const char* prefix, const char* name);
  void Bind(Label* label);

  void BindWithPowerOfTwoAlignment(const char* name, int power);

  void LocalBind(const char* name);

  void RelativeDefine(const char* name, const char* target, const char* base);

  void DefineLong(const char* name);
  void LoadNative(Register destination, Register index);
  void LoadLabel(Register reg, const char* name);

  // Align what follows to a 2^power address.
  void AlignToPowerOfTwo(int power);

 private:
  void Print(const char* format, ...);
  void PrintAddress(const Address* address);

  static const char* ConditionMnemonic(Condition condition);

  static const char* ComputeDirectionForLinking(Label* label);

  static int ComputeLabelPosition(Label* label);

  // Helper functions for wrapping operand types before passing them
  // through the va_args processing of Print(format, ...). The values
  // passed by reference are the problematic ones, but to make the
  // INSTRUCTION macros easier to write we have the trivial register
  // wrapper too.
  Register Wrap(Register reg) { return reg; }
  const Address* Wrap(const Address& address) { return &address; }
  const Immediate* Wrap(const Immediate& immediate) { return &immediate; }
};

#undef INSTRUCTION_0
#undef INSTRUCTION_1
#undef INSTRUCTION_2

}  // namespace dartino

#endif  // SRC_VM_ASSEMBLER_X64_H_
