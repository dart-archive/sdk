// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/object_memory.h"
#include "src/vm/program.h"
#include "src/vm/program_info_block.h"
#include "src/vm/snapshot.h"

#ifdef VERBOSE
#define DEBUG_PRINT(...) fprintf(stderr, __VA_ARGS__)
#else
#define DEBUG_PRINT(...)
#endif

namespace fletch {

// Helper class that can be used as a visitor when iterating pointers/roots
// to rebase them to a new address. It takes four arguments:
//
// from:        the address, in memory, of the source data structure
// target:      the address, in memory, of the mirror copy that is to be
//                updated
// host_base:   the base address, in memory, of the heap that from is
//                allocated from
// rebase_base: the base address, in the address space we are rebasing to, where
//                the heap that target is allocated from will be placed
//
// When iterating the roots of from, the visitor rewrites the corresponding
// addresses in target to the new base rebase_base.
class PointerRebasingVisitor : public PointerVisitor {
 public:
  PointerRebasingVisitor(uword from, uword target, uword host_base,
                         uword rebase_base)
      : from_(from),
        target_(target),
        host_base_(host_base),
        rebase_base_(rebase_base) {
  }

  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      if (!(*p)->IsHeapObject()) continue;
      Object** target_p = CorrespondingSlotInTarget(p);
      HeapObject* heap_p = HeapObject::cast(*p);
      uword value = heap_p->address();
      uword rebased = RebasePointerValue(value);
      DEBUG_PRINT("rewrite %lx -> %lx\n at %p", value, rebased, target_p);
      *target_p = HeapObject::FromAddress(rebased);
    }
  }

 private:
  Object** CorrespondingSlotInTarget(Object** slot) {
    uword slot_address = reinterpret_cast<uword>(slot);
    uword slot_offset = slot_address - from_;
    uword target = target_ + slot_offset;
    return reinterpret_cast<Object**>(target);
  }

  uword RebasePointerValue(uword value) {
    return (value - host_base_) + rebase_base_;
  }

  uword from_;
  uword target_;
  uword host_base_;
  uword rebase_base_;
};

// Helper class that can be used as a visitor when visiting all objects
// in a heap. It makes the assumption that the heap consists of a single
// continuous chunk of memory. It takes the following arguments:
//
// space_base:  the base address of the heap being traversed
// target_base: the base address of the shadow copy of the heap that is
//                rewritten
// rebase_base: the base address, in the relocated address space, where
//                the heap will be placed when used
class RelocationVisitor : public HeapObjectVisitor {
 public:
  RelocationVisitor(uword space_base, uword target_base, uword rebase_base)
      : space_base_(space_base),
        target_base_(target_base),
        rebase_base_(rebase_base) {
  }

  void Visit(HeapObject* from) {
    uword address = from->address();
    uword target_address = address - space_base_ + target_base_;

    HeapObject* target = HeapObject::FromAddress(target_address);
    PointerRebasingVisitor visitor(from->address(), target->address(),
                                   space_base_, rebase_base_);
    from->IteratePointers(&visitor);

    DEBUG_PRINT("relo %p -> %p [%p]\n", address, target_address,
           address - space_base_ + rebase_base_);
  }

 private:
  friend class PointerRebasingVisitor;

  uword space_base_;
  uword target_base_;
  uword rebase_base_;
};

class ProgramHeapRelocator {
 public:
  ProgramHeapRelocator(char* snapshot, const char* symbol, uword baseaddress)
      : snapshot_name_(snapshot),
        output_name_(symbol),
        baseaddress_(baseaddress) {}

  int Relocate() {
    ObjectMemory::Setup();
    List<uint8> bytes = Platform::LoadFile(snapshot_name_);
    SnapshotReader reader(bytes);
    Program* program = reader.ReadProgram();

    // Clear away the intrinsics as they will point to the wrong
    // addresses.
    program->ClearDispatchTableIntrinsics();

    // Make sure we only have one chunk in the heap so that we can linearly
    // relocate objects to the new base.
    Space* space = program->heap()->space();
    if (space->first() == NULL || space->first() != space->last()) {
      printf("We have more chunks than supported. Go fix the runtime!\n");
      return 1;
    }

    printf("Relocating %s to %lx\n", snapshot_name_, baseaddress_);

    Chunk* chunk = space->first();
    int heap_size = chunk->limit() - chunk->base();

    // heap + roots + main_arity
    int total_size = heap_size + sizeof(ProgramInfoBlock);
    List<uint8> target = List<uint8>::New(total_size);
    memcpy(reinterpret_cast<void*>(target.data()),
           reinterpret_cast<void*>(chunk->base()),
           heap_size);
    uword target_base = reinterpret_cast<uword>(target.data());

    RelocationVisitor relocator(chunk->base(), target_base, baseaddress_);

    program->heap()->space()->IterateObjects(&relocator);

    printf("Creating program with relocated roots...\n");

    ASSERT(program->session() == NULL);

    // Create a shadow copy of the program.
    Program* target_program =
        reinterpret_cast<Program*>(malloc(sizeof(Program)));
    memcpy(target_program, program, sizeof(Program));

    // Now fix up root pointers in the copy.
    PointerRebasingVisitor visitor(reinterpret_cast<uword>(program),
                                   reinterpret_cast<uword>(target_program),
                                   chunk->base(), baseaddress_);
    program->IterateRoots(&visitor);

    printf("Writing program with relocated roots...\n");

    // And write them to the end of the blob.
    // TODO(herhut): Use placement new here once supported by all toolchains.
    ProgramInfoBlock* program_info =
        reinterpret_cast<ProgramInfoBlock*>(target.data() + heap_size);
    program_info->PopulateFromProgram(target_program);

    Platform::StoreFile(output_name_, target);

    free(target_program);

    printf("Wrote total of %d bytes.\n", total_size);

    return 0;
  }

 private:
  const char* snapshot_name_;
  const char* output_name_;
  uword baseaddress_;
};

static int Main(int argc, char** argv) {
  if (argc < 4) {
    printf("Usage: %s <snapshot file> <base address> <program heap file>\n",
           argv[0]);
    return 1;
  }

  char* endptr;
  int64 basevalue;
  basevalue = strtoll(argv[2], &endptr, 0);
  if (*endptr != '\0' || basevalue < 0 || basevalue & 0x3) {
    printf("Illegal base address: %s [%" PRIx64 "]\n", argv[2], basevalue);
    return 1;
  }

  ProgramHeapRelocator relocator(argv[1], argv[3], basevalue);
  return relocator.Relocate();
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) {
  return fletch::Main(argc, argv);
}
