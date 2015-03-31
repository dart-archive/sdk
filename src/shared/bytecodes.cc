// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdarg.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/utils.h"

namespace fletch {

class StdoutWriter : public Bytecode::Writer {
 public:
  virtual ~StdoutWriter() { }

  void Write(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
  }
};

int Bytecode::Print(uint8* bcp, Writer* writer) {
  StdoutWriter stdout_writer;
  if (writer == NULL) writer = &stdout_writer;

  Opcode opcode = static_cast<Opcode>(*bcp);
  const char* bytecode_format = BytecodeFormat(opcode);
  const char* print_format = PrintFormat(opcode);

  if (strcmp(bytecode_format, "") == 0) {
    writer->Write(print_format);
  } else if (strcmp(bytecode_format, "B") == 0) {
    writer->Write(print_format, bcp[1]);
  } else if (strcmp(bytecode_format, "I") == 0) {
    writer->Write(print_format, Utils::ReadInt32(bcp + 1));
  } else if (strcmp(bytecode_format, "BB") == 0) {
    writer->Write(print_format, bcp[1], bcp[2]);
  } else if (strcmp(bytecode_format, "BI") == 0) {
    writer->Write(print_format, bcp[1], Utils::ReadInt32(bcp + 2));
  } else if (strcmp(bytecode_format, "II") == 0) {
    writer->Write(print_format,
                  Utils::ReadInt32(bcp + 1),
                  Utils::ReadInt32(bcp + 5));
  } else {
    FATAL1("Unknown bytecode format %s\n", bytecode_format);
  }
  return Size(opcode);
}

int Bytecode::sizes_[kNumBytecodes] = {
#define BYTECODE_SIZE(name, format, size, stack_diff, print) size,
  BYTECODES_DO(BYTECODE_SIZE)
#undef BYTECODE_SIZE
};

int Bytecode::Size(Opcode opcode) {
  return sizes_[opcode];
}

#define STR(string) #string

const char* Bytecode::PrintFormat(Opcode opcode) {
  const char* print_formats[kNumBytecodes] = {
#define BYTECODE_PRINT_FORMAT(name, format, size, stack_diff, print) \
    print,
  BYTECODES_DO(BYTECODE_PRINT_FORMAT)
#undef BYTECODE_PRINT_FORMAT
  };
  return print_formats[opcode];
}

const char* Bytecode::BytecodeFormat(Opcode opcode) {
  const char* bytecode_formats[kNumBytecodes] = {
#define BYTECODE_FORMAT(name, format, size, stack_diff, print) \
    format,
  BYTECODES_DO(BYTECODE_FORMAT)
#undef BYTECODE_FORMAT
  };
  return bytecode_formats[opcode];
}

int Bytecode::stack_diffs_[kNumBytecodes] = {
#define BYTECODE_STACK_DIFF(name, format, size, stack_diff, print) stack_diff,
  BYTECODES_DO(BYTECODE_STACK_DIFF)
#undef BYTECODE_STACK_DIFF
};

int Bytecode::StackDiff(Opcode opcode) {
  return stack_diffs_[opcode];
}

}  // namespace fletch
