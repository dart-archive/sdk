// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "include/fletch_api.h"
#include "src/vm/program_info_block.h"

namespace fletch {

extern "C" ProgramInfoBlock program_info_block;
extern "C" char program_start;
extern "C" char program_end;

static int Main(int argc, char** argv) {
  FletchSetup();

  char* heap = reinterpret_cast<char*>(&program_start);
  int heap_size = reinterpret_cast<char*>(&program_end) - heap;

  FletchProgram program = FletchLoadProgramFromFlash(heap, heap_size + sizeof(ProgramInfoBlock));
  int result = FletchRunMain(program);
  FletchDeleteProgram(program);

  FletchTearDown();
  return result;
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
