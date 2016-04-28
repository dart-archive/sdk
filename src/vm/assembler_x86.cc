// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_IA32)

#include <stdarg.h>  // NOLINT we don't include assembler_x86.h.
#include "src/vm/assembler.h"

namespace dartino {

enum RegisterSize {
  kLongRegister = 'l',
};

int Label::position_counter_ = 0;

void Assembler::j(Condition condition, Label* label) {
  const char* mnemonic = ConditionMnemonic(condition);
  printf("\tj%s %s%d\n", mnemonic, kLocalLabelPrefix, label->position());
}

void Assembler::jmp(Label* label) {
  printf("\tjmp %s%d\n", kLocalLabelPrefix, label->position());
}

void Assembler::SwitchToText() {
  puts("\n\t.text");
}

void Assembler::SwitchToData() {
  puts("\n\t.data");
}

void Assembler::BindWithPowerOfTwoAlignment(const char* name, int power) {
  AlignToPowerOfTwo(power);
  Bind("", name);
}

void Assembler::AlignToPowerOfTwo(int power) {
  printf("\t.p2align %d,0x90\n", power);
}

void Assembler::Bind(Label* label) {
  printf("%s%d:\n", kLocalLabelPrefix, label->position());
}

static const char* ToString(Register reg, RegisterSize size = kLongRegister) {
  static const char* kLongRegisterNames[] = {"%eax", "%ecx", "%edx", "%ebx",
                                             "%esp", "%ebp", "%esi", "%edi"};
  ASSERT(reg >= EAX && reg <= EDI);
  switch (size) {
    case kLongRegister:
      return kLongRegisterNames[reg];
  }
  UNREACHABLE();
  return NULL;
}

void Assembler::movl(Register reg, Label* label) {
  printf("\tmovl $%s%d, %s\n", kLocalLabelPrefix, label->position(),
         ToString(reg));
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

        case 'r': {
          RegisterSize size = static_cast<RegisterSize>(*++format);
          Register reg = static_cast<Register>(va_arg(arguments, int));
          printf("%s", ToString(reg, size));
          break;
        }

        case 'i': {
          // 32-bit immediate.
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("$%d", immediate->value());
          break;
        }

        case 'b': {
          // 8-bit immediate.
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          ASSERT(immediate->is_int8());
          printf("$%d", static_cast<uint8>(immediate->value()));
          break;
        }

        case 's': {
          printf("%s", va_arg(arguments, const char*));
          break;
        }

        case 'd': {
          printf("%d", va_arg(arguments, int));
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
  uint8 mod = address->mod();
  Register rm = address->rm();
  switch (mod) {
    case 0: {
      if (rm == EBP) {
        printf("%d", address->disp32());
      } else if (rm == ESP) {
        int scale = 1 << address->scale();
        Register base = address->base();
        Register index = address->index();
        if (index == ESP && base == ESP && scale == 1) {
          printf("(%s)", ToString(ESP));
        } else if (base == EBP) {
          printf("%d(,%s,%d)", address->disp32(), ToString(index), scale);
        } else {
          ASSERT(index != ESP && base != EBP);
          printf("(%s,%s,%d)", ToString(base), ToString(index), scale);
        }
      } else {
        printf("(%s)", ToString(rm));
      }
      break;
    }

    case 1:
    case 2: {
      int scale = 1 << address->scale();
      Register base = address->base();
      Register index = address->index();
      int disp = (mod == 2) ? address->disp32() : address->disp8();
      if (rm == ESP) {
        if (index == ESP && base == ESP && scale == 1) {
          printf("%d(%s)", disp, ToString(ESP));
        } else {
          printf("%d(%s,%s,%d)", disp, ToString(base), ToString(index), scale);
        }
      } else {
        printf("%d(%s)", disp, ToString(rm));
      }
      break;
    }

    default: {
      UNREACHABLE();
      break;
    }
  }
}

const char* Assembler::ConditionMnemonic(Condition condition) {
  static const char* kConditionMnemonics[] = {
      "o",   // OVERFLOW
      "no",  // NO_OVERFLOW
      "b",   // BELOW
      "ae",  // ABOVE_EQUAL
      "e",   // EQUAL
      "ne",  // NOT_EQUAL
      "be",  // BELOW_EQUAL
      "a",   // ABOVE
      "s",   // SIGN
      "ns",  // NOT_SIGN
      "p",   // PARITY_EVEN
      "np",  // PARITY_ODD
      "l",   // LESS
      "ge",  // GREATER_EQUAL
      "le",  // LESS_EQUAL
      "g"    // GREATER
  };
  ASSERT(static_cast<unsigned>(condition) < ARRAY_SIZE(kConditionMnemonics));
  return kConditionMnemonics[condition];
}

}  // namespace dartino

#endif  // defined DARTINO_TARGET_IA32
