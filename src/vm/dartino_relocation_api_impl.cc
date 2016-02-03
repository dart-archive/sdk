// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/dartino_relocation_api_impl.h"
#include "src/vm/object_memory.h"
#include "src/vm/program.h"
#include "src/vm/program_info_block.h"
#include "src/vm/program_relocator.h"

size_t DartinoGetProgramSize(DartinoProgram program) {
  dartino::Program* dartino_program =
      reinterpret_cast<dartino::Program*>(program);
  return
      dartino_program->program_heap_size() + sizeof(dartino::ProgramInfoBlock);
}

int DartinoRelocateProgram(DartinoProgram program, void* target,
                           uintptr_t base) {
  if (base % dartino::kPageSize != 0) return -1;
  dartino::Program* dartino_program =
      reinterpret_cast<dartino::Program*>(program);
  dartino::ProgramHeapRelocator relocator(
      dartino_program, reinterpret_cast<uint8*>(target), base);
  return relocator.Relocate();
}
