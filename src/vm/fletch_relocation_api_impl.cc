// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/fletch_relocation_api_impl.h"
#include "src/vm/object_memory.h"
#include "src/vm/program.h"
#include "src/vm/program_info_block.h"
#include "src/vm/program_relocator.h"

size_t FletchGetProgramSize(FletchProgram program) {
  fletch::Program* fletch_program = reinterpret_cast<fletch::Program*>(program);
  return fletch_program->program_heap_size() + sizeof(fletch::ProgramInfoBlock);
}

int FletchRelocateProgram(FletchProgram program, void* target, uintptr_t base) {
  if (base % fletch::kPageSize != 0) return -1;
  fletch::Program* fletch_program = reinterpret_cast<fletch::Program*>(program);
  fletch::ProgramHeapRelocator relocator(fletch_program,
                                         reinterpret_cast<uint8*>(target),
                                         base);
  return relocator.Relocate();
}
