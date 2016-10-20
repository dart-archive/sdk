// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/llvm_embedder.h"

#include <stdlib.h>

#include "include/dartino_api.h"
#include "src/vm/gc_llvm.h"
#include "src/vm/program_info_block.h"

namespace dartino {

extern "C" int program_start;
extern "C" int program_size;
extern "C" char program_info_block;

static int Main(int argc, char** argv) {
  StackMap::EnsureComputed();
  DartinoSetup();

  char* heap = reinterpret_cast<char*>(program_start);
  int heap_size = program_size;

  DartinoProgram program =
      DartinoLoadProgramFromFlashWide(heap, heap_size, &program_info_block);
  int result = DartinoRunMain(program, 0, NULL);
  DartinoDeleteProgram(program);

  DartinoTearDown();
  return result;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) {
  setbuf(stdout, NULL);
  return dartino::Main(argc, argv);
}
