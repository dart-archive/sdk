// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "include/dartino_api.h"

#include "src/shared/assert.h"
#include "src/shared/flags.h"

#include "src/vm/program.h"
#include "src/vm/program_info_block.h"

namespace dartino {

extern "C" void InterpreterMethodEntry();

class FlashifyVisitor : public HeapObjectVisitor {
 public:
  explicit FlashifyVisitor(int floating_point_size)
      : floating_point_size_(floating_point_size) {}

  virtual uword Visit(HeapObject* object) {
    printf("O%08lx:\n", object->address());
    FlashifyReference(object->get_class());
    if (object->IsClass()) {
      FlashifyClass(Class::cast(object));
    } else if (object->IsFunction()) {
      FlashifyFunction(Function::cast(object));
    } else if (object->IsInstance()) {
      FlashifyInstance(Instance::cast(object));
    } else if (object->IsOneByteString()) {
      FlashifyOneByteString(OneByteString::cast(object));
    } else if (object->IsTwoByteString()) {
      FlashifyTwoByteString(TwoByteString::cast(object));
    } else if (object->IsByteArray()) {
      FlashifyByteArray(ByteArray::cast(object));
    } else if (object->IsArray()) {
      FlashifyArray(Array::cast(object));
    } else if (object->IsLargeInteger()) {
      FlashifyLargeInteger(LargeInteger::cast(object));
    } else if (object->IsDouble()) {
      FlashifyDouble(Double::cast(object));
    } else if (object->IsInitializer()) {
      FlashifyInitializer(Initializer::cast(object));
    } else if (object->IsDispatchTableEntry()) {
      FlashifyDispatchTableEntry(DispatchTableEntry::cast(object));
    } else {
      FATAL1("Unhandled object type (%d) when flashifying!",
             object->format().type());
    }

    return object->Size();
  }

  void FlashifyReference(Object* object) {
    if (object->IsHeapObject()) {
      printf("\t.long O%08lx + 1\n", HeapObject::cast(object)->address());
    } else {
      printf("\t.long 0x%08lx\n", reinterpret_cast<uword>(object));
    }
  }

 private:
  void FlashifyClass(Class* clazz) {
    int size = clazz->AllocationSize();
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(clazz->at(offset));
    }
  }

  void FlashifyFunction(Function* function) {
    int size = Function::kSize;
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(function->at(offset));
    }

    for (int o = 0; o < function->bytecode_size(); o += kPointerSize) {
      printf("\t.long 0x%08lx\n",
             *reinterpret_cast<uword*>(function->bytecode_address_for(o)));
    }

    for (int i = 0; i < function->literals_size(); i++) {
      FlashifyReference(function->literal_at(i));
    }
  }

  void FlashifyInstance(Instance* instance) {
    int size = instance->Size();
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(instance->at(offset));
    }
  }

  void FlashifyOneByteString(OneByteString* string) {
    string->Hash();
    int size = OneByteString::kSize;
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(string->at(offset));
    }

    for (int o = size; o < string->StringSize(); o += kPointerSize) {
      printf("\t.long 0x%08lx\n",
             *reinterpret_cast<uword*>(string->byte_address_for(o - size)));
    }
  }

  void FlashifyTwoByteString(TwoByteString* string) {
    string->Hash();
    int size = TwoByteString::kSize;
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(string->at(offset));
    }

    for (int o = size; o < string->StringSize(); o += kPointerSize) {
      printf(
          "\t.long 0x%08lx\n",
          *reinterpret_cast<uword*>(string->byte_address_for((o - size) / 2)));
    }
  }

  void FlashifyByteArray(ByteArray* array) {
    int size = ByteArray::kSize;
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(array->at(offset));
    }

    for (int o = size; o < array->ByteArraySize(); o += kPointerSize) {
      printf("\t.long 0x%08lx\n",
             *reinterpret_cast<uword*>(array->byte_address_for(o - size)));
    }
  }

  void FlashifyArray(Array* array) {
    int size = array->Size();
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(array->at(offset));
    }
  }

  void FlashifyLargeInteger(LargeInteger* large) {
    uword* ptr =
        reinterpret_cast<uword*>(large->address() + LargeInteger::kValueOffset);
    printf("\t.long 0x%08lx\n", ptr[0]);
    printf("\t.long 0x%08lx\n", ptr[1]);
  }

  void FlashifyDouble(Double* d) {
    if (floating_point_size_ == 32) {
      float flt =
          *reinterpret_cast<double*>(d->address() + Double::kValueOffset);
      uword* ptr = reinterpret_cast<uword*>(&flt);
      printf("\t.long 0x%08lx\n", ptr[0]);
    } else {
      ASSERT(floating_point_size_ == 64);
      uword* ptr =
          reinterpret_cast<uword*>(d->address() + Double::kValueOffset);
      printf("\t.long 0x%08lx\n", ptr[0]);
      printf("\t.long 0x%08lx\n", ptr[1]);
    }
  }

  void FlashifyInitializer(Initializer* initializer) {
    int size = initializer->Size();
    for (int offset = HeapObject::kSize; offset < size;
         offset += kPointerSize) {
      FlashifyReference(initializer->at(offset));
    }
  }

  void FlashifyDispatchTableEntry(DispatchTableEntry* entry) {
    FlashifyReference(entry->target());
    void* code = entry->code();
    if (code == &Intrinsic_ObjectEquals) {
      printf("\t.long Intrinsic_ObjectEquals\n");
    } else if (code == &Intrinsic_GetField) {
      printf("\t.long Intrinsic_GetField\n");
    } else if (code == &Intrinsic_SetField) {
      printf("\t.long Intrinsic_SetField\n");
    } else if (code == &Intrinsic_ListIndexGet) {
      printf("\t.long Intrinsic_ListIndexGet\n");
    } else if (code == &Intrinsic_ListIndexSet) {
      printf("\t.long Intrinsic_ListIndexSet\n");
    } else if (code == &Intrinsic_ListLength) {
      printf("\t.long Intrinsic_ListLength\n");
    } else if (code == &InterpreterMethodEntry) {
      printf("\t.long InterpreterMethodEntry\n");
    } else {
      FATAL("Unhandled code pointer in dispatch table entry.");
    }
    FlashifyReference(entry->offset());
    printf("\t.long 0x%08lx\n", entry->selector());
  }

  int floating_point_size_;
};

static void FlashifyProgram(Program* program, int floating_point_size) {
  FlashifyVisitor visitor(floating_point_size);

  printf("\t.section .rodata\n\n");

  printf("\t.global program_start\n");
  printf("\t.p2align 12\n");
  printf("program_start:\n");

  program->heap()->space()->IterateObjects(&visitor);

  printf("\t.global program_end\n");
  printf("\t.p2align 12\n");
  printf("program_end:\n\n");

  ProgramInfoBlock* block = new ProgramInfoBlock();
  block->PopulateFromProgram(program);
  printf("\t.global program_info_block\n");
  printf("program_info_block:\n");

  printf("\t.long 0x%08lx\n", block->magic());
  printf("\t.long 0x%08x\n", block->snapshot_hash());

  for (Object** r = block->roots(); r < block->end_of_roots(); r++) {
    visitor.FlashifyReference(*r);
  }

  printf("\t.global program_info_block_end\n");
  printf("program_info_block_end:\n");

  delete block;
}

static void PrintUsage(char* executable) {
  fprintf(stderr,
          "Usage: %s [--floating-point-size=32|64] "
          "<snapshot> <output file name>\n",
          executable);
}

static bool StartsWith(const char* s, const char* prefix) {
  return strncmp(s, prefix, strlen(prefix)) == 0;
}

static int Main(int argc, char** argv) {
#ifdef DARTINO64
  fprintf(stderr, "The 64-bit version of this tool is unimplemented.\n");
  exit(1);
#endif
  // uword is used for writing .long values.
  ASSERT(sizeof(uword) == 32);

  Flags::ExtractFromCommandLine(&argc, argv);

  bool invalid_option = false;
  int floating_point_size = 64;

  const char* kFloatingPointSizeOption = "--floating-point-size=";

  // Process all options.
  char* executable = argv[0];
  argc--;
  argv++;
  while (argc > 0) {
    const char* argument = argv[0];
    if (!StartsWith(argument, "-")) break;
    argc--;
    argv++;
    if (StartsWith(argument, kFloatingPointSizeOption)) {
      int prefix_length = strlen(kFloatingPointSizeOption);
      floating_point_size = atoi(argument + prefix_length);
      if (floating_point_size != 32 && floating_point_size != 64) {
        Print::Out("Invalid value for --floating-point-size: %s.\n",
                   argument + prefix_length);
        invalid_option = true;
      }
    } else {
      Print::Out("Invalid option: %s.\n", argument);
      invalid_option = true;
    }
  }

  // Don't continue if one or more invalid/unknown options were passed
  // or filenames where missing.
  if (invalid_option || argc != 2) {
    fprintf(stderr, "\n");
    PrintUsage(executable);
    exit(1);
  }

  char* snapshot_file = argv[0];
  char* output_file = argv[1];
  if (freopen(output_file, "w", stdout) == NULL) {
    fprintf(stderr, "%s: Cannot open '%s' for writing.\n",
            executable, output_file);
    exit(1);
  }

  DartinoSetup();

  DartinoProgram program = DartinoLoadSnapshotFromFile(snapshot_file);
  FlashifyProgram(reinterpret_cast<Program*>(program), floating_point_size);
  DartinoDeleteProgram(program);

  DartinoTearDown();
  return 0;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }
