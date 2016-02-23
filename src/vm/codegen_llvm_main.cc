// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "include/dartino_api.h"
#include "src/shared/flags.h"
#include "src/vm/codegen_llvm.h"

namespace dartino {

static void GenerateLLVMCode(Program* program, const char* bitcode_file) {
  LLVMCodegen codegen(program);
  codegen.Generate(bitcode_file, true, false);
}

static int Main(int argc, char** argv) {
  Flags::ExtractFromCommandLine(&argc, argv);

  if (argc != 3) {
    fprintf(stderr, "Usage: %s <snapshot> <output file name>\n", argv[0]);
    exit(1);
  }

  if (freopen(argv[2], "w", stdout) == NULL) {
    fprintf(stderr, "%s: Cannot open '%s' for writing.\n", argv[0], argv[2]);
    exit(1);
  }

  DartinoSetup();
  DartinoProgram api_program = DartinoLoadSnapshotFromFile(argv[1]);

  Program* program = reinterpret_cast<Program*>(api_program);

  GenerateLLVMCode(program, argv[2]);

  DartinoDeleteProgram(api_program);
  DartinoTearDown();
  return 0;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) {

  // Disable printf() buffering!
  setbuf(stdout, NULL);

  return dartino::Main(argc, argv);
}
