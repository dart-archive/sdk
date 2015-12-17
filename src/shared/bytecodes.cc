// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdarg.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/utils.h"

namespace fletch {

uint8 Bytecode::Print(uint8* bcp) {
  Opcode opcode = static_cast<Opcode>(*bcp);
  const char* bytecode_format = BytecodeFormat(opcode);
  const char* print_format = PrintFormat(opcode);

  if (strcmp(bytecode_format, "") == 0) {
    Print::Out(print_format);
  } else if (strcmp(bytecode_format, "B") == 0) {
    Print::Out(print_format, bcp[1]);
  } else if (strcmp(bytecode_format, "I") == 0) {
    Print::Out(print_format, Utils::ReadInt32(bcp + 1));
  } else if (strcmp(bytecode_format, "BB") == 0) {
    Print::Out(print_format, bcp[1], bcp[2]);
  } else if (strcmp(bytecode_format, "IB") == 0) {
    Print::Out(print_format, Utils::ReadInt32(bcp + 1), bcp[5]);
  } else if (strcmp(bytecode_format, "BI") == 0) {
    Print::Out(print_format, bcp[1], Utils::ReadInt32(bcp + 2));
  } else if (strcmp(bytecode_format, "II") == 0) {
    Print::Out(print_format, Utils::ReadInt32(bcp + 1),
               Utils::ReadInt32(bcp + 5));
  } else {
    FATAL1("Unknown bytecode format %s\n", bytecode_format);
  }
  return Size(opcode);
}

uint8 Bytecode::Size(Opcode opcode) {
  const uint8 sizes[kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) size,
      BYTECODES_DO(EACH)
#undef EACH
  };
  ASSERT(opcode < kNumBytecodes);
  return sizes[opcode];
}

#define STR(string) #string

const char* Bytecode::PrintFormat(Opcode opcode) {
  const char* print_formats[kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) print,
      BYTECODES_DO(EACH)
#undef EACH
  };
  ASSERT(opcode < kNumBytecodes);
  return print_formats[opcode];
}

const char* Bytecode::BytecodeFormat(Opcode opcode) {
  const char* bytecode_formats[kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) format,
      BYTECODES_DO(EACH)
#undef EACH
  };
  ASSERT(opcode < kNumBytecodes);
  return bytecode_formats[opcode];
}

int8 Bytecode::StackDiff(Opcode opcode) {
  const int8 stack_diffs[kNumBytecodes] = {
#define EACH(name, branching, format, size, stack_diff, print) stack_diff,
      BYTECODES_DO(EACH)
#undef EACH
  };
  ASSERT(opcode < kNumBytecodes);
  return stack_diffs[opcode];
}

bool Bytecode::IsInvokeVariant(Opcode opcode) {
  return IsInvoke(opcode) || IsInvokeUnfold(opcode);
}

bool Bytecode::IsInvokeUnfold(Opcode opcode) {
  return opcode >= kInvokeMethodUnfold && opcode <= kInvokeFactoryUnfold;
}

bool Bytecode::IsInvoke(Opcode opcode) {
  return opcode >= kInvokeMethod && opcode <= kInvokeFactory;
}

// TODO(ager): use branches to skip forward by more than
// a bytecode at a time.
uint8* Bytecode::PreviousBytecode(uint8* current_bcp) {
  uint8* bcp = current_bcp;
  while (*bcp != kMethodEnd) {
    bcp += Bytecode::Size(static_cast<Opcode>(*bcp));
  }
  int value = Utils::ReadInt32(bcp + 1);
  int delta = value >> 1;
  bcp -= delta;
  uint8* previous = NULL;
  while (bcp != current_bcp) {
    previous = bcp;
    bcp += Bytecode::Size(static_cast<Opcode>(*bcp));
  }
  return previous;
}

}  // namespace fletch
