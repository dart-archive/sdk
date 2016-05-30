// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_MIPS)

#include "src/vm/assembler.h" // NOLINT we don't include assembler_mips.h.

#include <stdio.h>
#include <stdarg.h>

namespace dartino {

int Label::position_counter_ = 0;

static const char* ConditionToString(Condition cond) {
  static const char* kConditionNames[] = {  "f",   "t",  "un",   "or",  "eq",
                                           "ne", "ueq", "olg",  "olt", "uge",
                                          "ult", "oge", "ole",  "ugt", "ule",
                                          "ogt",  "sf",  "st", "ngle", "gle",
                                          "seq", "sne", "ngl",   "gl",  "lt",
                                          "nlt", "nge",  "ge",   "le", "nle",
                                          "ngt",  "gt"};
  return kConditionNames[cond];
}

void Assembler::BindWithPowerOfTwoAlignment(const char* name, int power) {
  AlignToPowerOfTwo(power);
  printf("\t.globl %s%s\n%s%s:\n", LabelPrefix(), name, LabelPrefix(), name);
}

void Assembler::AlignToPowerOfTwo(int power) {
  printf("\t.align %d\n", power);
}

void Assembler::Bind(Label* label) {
  printf(".L%d:\n", label->position());
}

void Assembler::SwitchToText() {
  puts("\n\t.text");
}

void Assembler::SwitchToData() {
  puts("\n\t.data");
}

static const char* ToString(Register reg) {
  static const char* kRegisterNames[] = {"zero", "at", "v0", "v1", "a0", "a1",
                                         "a2", "a3", "t0", "t1", "t2", "t3",
                                         "t4", "t5", "t6", "t7", "s0", "s1",
                                         "s2", "s3", "s4", "s5", "s6", "s7",
                                         "t8", "t9", "k0", "k1", "gp", "sp",
                                         "fp", "ra"};
  ASSERT(reg >= ZR && reg <= RA);
  return kRegisterNames[reg];
}

void Assembler::Print(const char* format, ...) {
  printf("\t");
  va_list arguments;
  va_start(arguments, format);
  while (*format != '\0') {
    if (*format == '%') {
      format++;
      switch (*format) {
        case '%': {
          putchar('%');
          break;
        }

        case 'a': {
          const Address* address = va_arg(arguments, const Address*);
          PrintAddress(address);
          break;
        }

        case 'c': {
          Condition condition = static_cast<Condition>(va_arg(arguments, int));
          printf("%s", ConditionToString(condition));
          break;
        }

        case 'l': {
          Label* label = va_arg(arguments, Label*);
          printf(".L%d", label->position());
          break;
        }

        case 'r': {
          Register reg = static_cast<Register>(va_arg(arguments, int));
          printf("$%s", ToString(reg));
          break;
        }

        case 'i': {
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("%d", immediate->value());
          break;
        }

        case 's': {
          const char* label = va_arg(arguments, const char*);
          printf("%s%s", LabelPrefix(), label);
          break;
        }

        default: {
          UNREACHABLE();
          break;
        }
      }
    } else {
      putchar(*format);
    }
    format++;
  }
  va_end(arguments);
  putchar('\n');
}

void Assembler::PrintAddress(const Address* address) {
  printf("%d($%s)", address->offset(), ToString(address->base()));
}

}  // namespace dartino

#endif  // defined(DARTINO_TARGET_MIPS)
