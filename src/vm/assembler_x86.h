// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_X86_H_
#define SRC_VM_ASSEMBLER_X86_H_

#ifndef SRC_VM_ASSEMBLER_H_
#error Do not include assembler_x86.h directly; use assembler.h instead.
#endif

#include "src/shared/assert.h"
#include "src/shared/utils.h"

namespace fletch {

enum Register {
  EAX = 0,
  ECX = 1,
  EDX = 2,
  EBX = 3,
  ESP = 4,
  EBP = 5,
  ESI = 6,
  EDI = 7
};

enum ScaleFactor {
  TIMES_1 = 0,
  TIMES_2 = 1,
  TIMES_4 = 2,
  TIMES_WORD_SIZE = TIMES_4,
  TIMES_8 = 3
};

enum Condition {
  OVERFLOW_ = 0,  // TODO(kasperl): Rename this.
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
  explicit Immediate(int32 value) : value_(value) {}

  int32 value() const { return value_; }

  bool is_int8() const { return Utils::IsInt8(value_); }

 private:
  const int32 value_;
};

class Operand {
 public:
  uint8 mod() const { return (EncodingAt(0) >> 6) & 3; }

  Register rm() const { return static_cast<Register>(EncodingAt(0) & 7); }

  ScaleFactor scale() const {
    return static_cast<ScaleFactor>((EncodingAt(1) >> 6) & 3);
  }

  Register index() const {
    return static_cast<Register>((EncodingAt(1) >> 3) & 7);
  }

  Register base() const { return static_cast<Register>(EncodingAt(1) & 7); }

  int8 disp8() const {
    ASSERT(length_ >= 2);
    return *reinterpret_cast<const int8*>(&encoding_[length_ - 1]);
  }

  int32 disp32() const {
    ASSERT(length_ >= 5);
    return *reinterpret_cast<const int32*>(&encoding_[length_ - 4]);
  }

  bool IsRegister(Register reg) const {
    return ((encoding_[0] & 0xF8) == 0xC0)  // Addressing mode is register only.
           && ((encoding_[0] & 0x07) == reg);  // Register codes match.
  }

 protected:
  Operand() : length_(0) {}

  void SetModRM(int mod, Register rm) {
    ASSERT((mod & ~3) == 0);
    encoding_[0] = (mod << 6) | rm;
    length_ = 1;
  }

  void SetSIB(ScaleFactor scale, Register index, Register base) {
    ASSERT(length_ == 1);
    ASSERT((scale & ~3) == 0);
    encoding_[1] = (scale << 6) | (index << 3) | base;
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
  uint8 encoding_[6];
  uint8 padding_;

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
    if (disp == 0 && base != EBP) {
      SetModRM(0, base);
      if (base == ESP) SetSIB(TIMES_1, ESP, base);
    } else if (Utils::IsInt8(disp)) {
      SetModRM(1, base);
      if (base == ESP) SetSIB(TIMES_1, ESP, base);
      SetDisp8(disp);
    } else {
      SetModRM(2, base);
      if (base == ESP) SetSIB(TIMES_1, ESP, base);
      SetDisp32(disp);
    }
  }

  Address(Register index, ScaleFactor scale, int32 disp = 0) {
    ASSERT(index != ESP);  // Illegal addressing mode.
    SetModRM(0, ESP);
    SetSIB(scale, index, EBP);
    SetDisp32(disp);
  }

  Address(Register base, Register index, ScaleFactor scale, int32 disp = 0) {
    ASSERT(index != ESP);  // Illegal addressing mode.
    if (disp == 0 && base != EBP) {
      SetModRM(0, ESP);
      SetSIB(scale, index, base);
    } else if (Utils::IsInt8(disp)) {
      SetModRM(1, ESP);
      SetSIB(scale, index, base);
      SetDisp8(disp);
    } else {
      SetModRM(2, ESP);
      SetSIB(scale, index, base);
      SetDisp32(disp);
    }
  }
};

class Label {
 public:
  Label() : position_(0) {}

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
  void name(t0 a0, t1 a1) { Print(format, Wrap(a1), Wrap(a0)); }

class Assembler {
 public:
  INSTRUCTION_1(pushl, "pushl %rl", Register);
  INSTRUCTION_1(pushl, "pushl %a", const Address&);
  INSTRUCTION_1(pushl, "pushl %i", const Immediate&);

  INSTRUCTION_1(popl, "popl %rl", Register);
  INSTRUCTION_1(popl, "popl %a", const Address&);

  INSTRUCTION_1(notl, "notl %rl", Register);
  INSTRUCTION_1(negl, "negl %rl", Register);
  INSTRUCTION_1(incl, "incl %rl", Register);
  INSTRUCTION_1(idiv, "idiv %rl", Register);
  INSTRUCTION_1(imul, "imul %rl", Register);

  INSTRUCTION_1(call, "call *%rl", Register);
  INSTRUCTION_1(call, "call *%a", const Address&);

  INSTRUCTION_1(jmp, "jmp *%rl", Register);
  INSTRUCTION_1(jmp, "jmp *%a", const Address&);

  INSTRUCTION_2(movl, "movl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(movl, "movl %i, %a", const Address&, const Immediate&);
  INSTRUCTION_2(movl, "movl %rl, %rl", Register, Register);

  INSTRUCTION_2(movl, "movl %a, %rl", Register, const Address&);
  INSTRUCTION_2(movl, "movl %rl, %a", const Address&, Register);

  INSTRUCTION_2(leal, "leal %a, %rl", Register, const Address&);
  INSTRUCTION_2(movzbl, "movzbl %a, %rl", Register, const Address&);

  INSTRUCTION_2(cmpl, "cmpl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(cmpl, "cmpl %i, %a", const Address&, const Immediate&);
  INSTRUCTION_2(cmpl, "cmpl %rl, %rl", Register, Register);
  INSTRUCTION_2(cmpl, "cmpl %a, %rl", Register, const Address&);

  INSTRUCTION_2(testl, "testl %rl, %rl", Register, Register);
  INSTRUCTION_2(testl, "testl %i, %rl", Register, const Immediate&);

  INSTRUCTION_2(addl, "addl %rl, %rl", Register, Register);
  INSTRUCTION_2(addl, "addl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(addl, "addl %i, %a", const Address&, const Immediate&);

  INSTRUCTION_2(andl, "andl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(andl, "andl %rl, %rl", Register, Register);
  INSTRUCTION_2(andl, "andl %a, %rl", Register, const Address&);

  INSTRUCTION_2(subl, "subl %rl, %rl", Register, Register);
  INSTRUCTION_2(subl, "subl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(subl, "subl %i, %a", const Address&, const Immediate&);

  INSTRUCTION_2(sarl, "sarl %i, %rl", Register, const Immediate&);
  INSTRUCTION_1(sarl_cl, "sarl %%cl, %rl", Register);

  INSTRUCTION_2(shrl, "shrl %i, %rl", Register, const Immediate&);
  INSTRUCTION_2(shll, "shll %i, %rl", Register, const Immediate&);
  INSTRUCTION_1(shll_cl, "shll %%cl, %rl", Register);

  INSTRUCTION_2(orl, "orl %rl, %rl", Register, Register);
  INSTRUCTION_2(xorl, "xorl %rl, %rl", Register, Register);

  INSTRUCTION_0(cdq, "cdq");
  INSTRUCTION_0(ret, "ret");
  INSTRUCTION_0(nop, "nop");
  INSTRUCTION_0(int3, "int3");

  void movl(Register reg, Label* label);

  void j(Condition condition, const char* name);
  void j(Condition condition, Label* label);

  void call(const char* name);

  void jmp(const char* name);
  void jmp(const char* name, Register index, ScaleFactor scale);
  void jmp(Label* label);

  void Bind(const char* prefix, const char* name);
  void BindWithPowerOfTwoAlignment(const char* name, int power);
  void Bind(Label* label);

  void DefineLong(const char* name);
  void LoadNative(Register destination, Register index);

  void SwitchToText();
  void SwitchToData();

  // Align what follows to a 2^power address.
  void AlignToPowerOfTwo(int power);

 private:
  void Print(const char* format, ...);
  void PrintAddress(const Address* address);

  static const char* ConditionMnemonic(Condition condition);

  static const char* ComputeDirectionForLinking(Label* label);
  static int NewLabelPosition();

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

}  // namespace fletch

#endif  // SRC_VM_ASSEMBLER_X86_H_
