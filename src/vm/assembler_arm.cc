// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_ARM)

#include "src/vm/assembler.h"

#include <stdio.h>
#include <stdarg.h>

namespace fletch {

void Assembler::Align(int alignment) {
  printf("\t.align %d\n", alignment);
}

void Assembler::Bind(Label* label) {
  if (label->IsUnused()) {
    label->BindTo(NewLabelPosition());
  } else {
    label->BindTo(label->position());
  }
  printf("%d:\n", label->position());
}

static const char* ToString(Register reg) {
  static const char* kRegisterNames[] = {
    "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8",
    "r9", "r10", "r11", "ip", "sp", "lr", "pc"
  };
  ASSERT(reg >= R0 && reg <= R15);
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

        case 'r': {
          Register reg = static_cast<Register>(va_arg(arguments, int));
          printf("%s", ToString(reg));
          break;
        }

        case 'i': {
          const Immediate* immediate = va_arg(arguments, const Immediate*);
          printf("#%d", immediate->value());
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

int Assembler::NewLabelPosition() {
  static int labels = 0;
  return labels++;
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_ARM)
