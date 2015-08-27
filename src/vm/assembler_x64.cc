// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_X64)

#include <stdarg.h>  // NOLINT we don't include assembler_x64.h
#include "src/vm/assembler.h"

namespace fletch {

enum RegisterSize {
  kLongRegister = 'l',
  kQuadRegister = 'q'
};

void Assembler::j(Condition condition, Label* label) {
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
  const char* mnemonic = kConditionMnemonics[condition];
  printf("\tj%s L%d\n", mnemonic, ComputeLabelPosition(label));
}

void Assembler::AlignToPowerOfTwo(int power) {
  printf("\t.p2align %d,0x90\n", power);
}

void Assembler::jmp(Label* label) {
  printf("\tjmp L%d\n", ComputeLabelPosition(label));
}

void Assembler::Bind(Label* label) {
  printf("L%d:\n", ComputeLabelPosition(label));
}

static const char* ToString(Register reg, RegisterSize size = kQuadRegister) {
  static const char* kLongRegisterNames[] =
      { "%eax", "%ecx", "%edx",  "%ebx",  "%esp",  "%ebp",  "%esi",  "%edi",
        "%r8d", "%r9d", "%r10d", "%r11d", "%r12d", "%r13d", "%r14d", "%r15d"
      };
  static const char* kQuadRegisterNames[] =
      { "%rax", "%rcx", "%rdx", "%rbx", "%rsp", "%rbp", "%rsi", "%rdi",
        "%r8",  "%r9",  "%r10", "%r11", "%r12", "%r13", "%r14", "%r15"
      };
  ASSERT(reg >= RAX && reg <= R15);
  switch (size) {
    case kLongRegister: return kLongRegisterNames[reg];
    case kQuadRegister: return kQuadRegisterNames[reg];
  }
  UNREACHABLE();
  return NULL;
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
          ASSERT(immediate->is_int32());
          printf("$%d", static_cast<int32>(immediate->value()));
          break;
        }

        case 'l': {
          // 64-bit immediate. Only used for movq instructions.
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("$%ld", immediate->value());
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
      if (rm == RBP) {
        printf("%d", address->disp32());
      } else if (rm == RSP || rm == R12) {
        int scale = 1 << address->scale();
        Register base = address->base();
        Register index = address->index();
        if (index == RSP && base == RSP && scale == 1) {
          printf("(%s)", ToString(RSP));
        } else if (base == RBP) {
          printf("%d(,%s,%d)", address->disp32(), ToString(index), scale);
        } else {
          ASSERT(index != RSP && base != RBP);
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
      if (rm == RSP || rm == R12) {
        if (index == RSP && base == RSP && scale == 1) {
          printf("%d(%s)", disp, ToString(RSP));
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

int Assembler::ComputeLabelPosition(Label* label) {
  if (!label->IsBound()) {
    static int labels = 0;
    label->BindTo(++labels);
  }
  return label->position();
}

}  // namespace fletch

#endif  // defined FLETCH_TARGET_X64
