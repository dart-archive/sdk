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
  virtual int Visit(HeapObject* object) {
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
    uword* ptr = reinterpret_cast<uword*>(d->address() + Double::kValueOffset);
    printf("\t.long 0x%08lx\n", ptr[0]);
    printf("\t.long 0x%08lx\n", ptr[1]);
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
};

static void FlashifyProgram(Program* program) {
  FlashifyVisitor visitor;

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

  for (Object** r = block->roots(); r < block->end_of_roots(); r++) {
    visitor.FlashifyReference(*r);
  }

  delete block;
}

static int Main(int argc, char** argv) {
#ifdef DARTINO64
  fprintf(stderr, "The 64-bit version of this tool is unimplemented.\n");
  exit(1);
#endif

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

  DartinoProgram program = DartinoLoadSnapshotFromFile(argv[1]);
  FlashifyProgram(reinterpret_cast<Program*>(program));
  DartinoDeleteProgram(program);

  DartinoTearDown();
  return 0;
}

}  // namespace dartino

// Forward main calls to dartino::Main.
int main(int argc, char** argv) { return dartino::Main(argc, argv); }
