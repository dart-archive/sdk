// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/intrinsics.h"
#include "src/vm/object_memory.h"
#include "src/vm/program.h"
#include "src/vm/program_info_block.h"
#include "src/vm/program_relocator.h"
#include "src/vm/snapshot.h"

namespace dartino {

// Create some fake symbols to satisfy dependencies from the missing
// interpreter.
#define DEFINE_INTRINSIC(name_) void Intrinsic_##name_() { \
  FATAL("Intrinsics_" #name_ " not implemented.");         \
}
  INTRINSICS_DO(DEFINE_INTRINSIC)
#undef DEFINE_INTRINSIC

extern "C" void InterpreterMethodEntry() {
  FATAL("InterpreterMethodEntry not implemented.");
}

static void printUsage(char* name) {
  printf(
      "Usage: %s [-i <intrinsic name>=<address>] <snapshot file> "
      "<base address> <program heap file>\n",
      name);
}

static int Main(int argc, char** argv) {
  IntrinsicsTable* table = new IntrinsicsTable();

  char** argp = argv + 1;
  while (argc > 4) {
    if (strcmp(*(argp++), "-i") != 0) {
      printUsage(*argv);
      return 1;
    }
    char* name;
    char* value;
    char* safe_ptr = NULL;
    if ((name = strtok_r(*argp++, "=", &safe_ptr)) == NULL ||
        (value = strtok_r(NULL, "=", &safe_ptr)) == NULL ||
        strtok_r(NULL, "=", &safe_ptr) != NULL) {
      printUsage(*argv);
      return 1;
    }
    char* endptr;
    int64 address = strtoll(value, &endptr, 0);
    if (*endptr != '\0' || address < 0) {
      printf("Illegal address for intrinsic %s: %" PRIx64 "\n", name, address);
      return 1;
    }
    if (!table->set_from_string(name,
                                reinterpret_cast<void (*)(void)>(address))) {
      printf("Illegal intrinsic name: %s\n", name);
    }
    argc = argc - 2;
  }

  if (argc < 4) {
    printUsage(*argv);
    return 1;
  }

  char* endptr;
  int64 basevalue;
  basevalue = strtoll(argp[1], &endptr, 0);
  if (*endptr != '\0' || basevalue < 0 || basevalue & 0x3) {
    printf("Illegal base address: %s [%" PRIx64 "]\n", argp[1], basevalue);
    return 1;
  }

  ObjectMemory::Setup();
  List<uint8> bytes = Platform::LoadFile(argp[0]);
  SnapshotReader reader(bytes);
  Program* program = reader.ReadProgram();

  int size = program->program_heap_size() + sizeof(ProgramInfoBlock);
  List<uint8> result = List<uint8>::New(size);
  ProgramHeapRelocator relocator(program, result.data(), basevalue, table);
  relocator.Relocate();

  Platform::StoreFile(argp[2], result);

  result.Delete();
  return 0;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }
