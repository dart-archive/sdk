// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_ARM)

#include "src/vm/assembler.h"  // NOLINT we don't include assembler_arm.h.

#include <stdio.h>
#include <stdarg.h>

namespace fletch {

int Label::position_counter_ = 0;

static const char* ConditionToString(Condition cond) {
  static const char* kConditionNames[] = {"eq", "ne", "cs", "cc", "mi",
                                          "pl", "vs", "vc", "hi", "ls",
                                          "ge", "lt", "gt", "le", ""};
  return kConditionNames[cond];
}

void Assembler::LoadInt(Register reg, int value) {
  if (value >= 0 && value <= 255) {
    mov(reg, Immediate(value));
  } else if (value < 0 && value >= -256) {
    mvn(reg, Immediate(-(value + 1)));
  } else {
    ldr(reg, Immediate(value));
  }
}

void Assembler::BindWithPowerOfTwoAlignment(const char* name, int power) {
  AlignToPowerOfTwo(power);
  printf("\t.global %s%s\n%s%s:\n", LabelPrefix(), name, LabelPrefix(), name);
}

void Assembler::AlignToPowerOfTwo(int power) {
  printf("\t.p2align %d\n", power);
}

void Assembler::Bind(Label* label) {
  printf(".L%d:\n", label->position());
}

void Assembler::GenerateConstantPool() { printf(".ltorg\n"); }

void Assembler::SwitchToText() {
  puts("\n\t.text");
}

void Assembler::SwitchToData() {
  puts("\n\t.data");
}

static const char* ToString(Register reg) {
  static const char* kRegisterNames[] = {"r0", "r1", "r2", "r3", "r4",  "r5",
                                         "r6", "r7", "r8", "r9", "r10", "r11",
                                         "ip", "sp", "lr", "pc"};
  ASSERT(reg >= R0 && reg <= R15);
  return kRegisterNames[reg];
}

static void PrintRegisterList(RegisterList regs) {
  bool first = true;
  for (int r = 0; r < 16; r++) {
    if ((regs & (1 << r)) != 0) {
      if (first) {
        printf("%s", ToString(static_cast<Register>(r)));
        first = false;
      } else {
        printf(", %s", ToString(static_cast<Register>(r)));
      }
    }
  }
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
          printf("%s", ToString(reg));
          break;
        }

        case 'R': {
          RegisterList regs =
              static_cast<RegisterList>(va_arg(arguments, int32_t));
          PrintRegisterList(regs);
          break;
        }

        case 'i': {
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("#%d", immediate->value());
          break;
        }

        case 'I': {
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("=%d", immediate->value());
          break;
        }

        case 'o': {
          const Operand* operand = va_arg(arguments, const Operand*);
          PrintOperand(operand);
          break;
        }

        case 's': {
          const char* label = va_arg(arguments, const char*);
          printf("%s%s", LabelPrefix(), label);
          break;
        }

        case 'W': {
#ifdef FLETCH_THUMB_ONLY
          UNREACHABLE();
#else
          WriteBack write_back = static_cast<WriteBack>(va_arg(arguments, int));
          if (write_back == WRITE_BACK) {
            putchar('!');
          }
#endif
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
  if (address->kind() == Address::IMMEDIATE) {
    printf("[%s, #%d]", ToString(address->base()), address->offset());
  } else {
    ASSERT(address->kind() == Address::OPERAND);
    printf("[%s, ", ToString(address->base()));
    PrintOperand(address->operand());
    printf("]");
  }
}

static const char* ShiftTypeToString(ShiftType type) {
  static const char* kShiftNames[] = {"lsl", "asr"};
  return kShiftNames[type];
}

void Assembler::PrintOperand(const Operand* operand) {
  printf("%s, %s #%d", ToString(operand->reg()),
         ShiftTypeToString(operand->shift_type()), operand->shift_amount());
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_ARM)
