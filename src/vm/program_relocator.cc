// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"

#include "src/vm/program_info_block.h"
#include "src/vm/program_relocator.h"

#ifdef VERBOSE
#define DEBUG_PRINT(...) fprintf(stderr, __VA_ARGS__)
#else
#define DEBUG_PRINT(...)
#endif

namespace dartino {

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
        rebase_base_(rebase_base) {}

  void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      if (!(*p)->IsHeapObject()) continue;
      Object** target_p = CorrespondingSlotInTarget(p);
      HeapObject* heap_p = HeapObject::cast(*p);
      uword value = heap_p->address();
      uword rebased = RebasePointerValue(value);
      DEBUG_PRINT("rewrite %lx -> %lx at %p\n", value, rebased, target_p);
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
        rebase_base_(rebase_base) {}

  int Visit(HeapObject* from) {
    uword address = from->address();
    uword target_address = address - space_base_ + target_base_;

    HeapObject* target = HeapObject::FromAddress(target_address);
    PointerRebasingVisitor visitor(from->address(), target->address(),
                                   space_base_, rebase_base_);
    from->IteratePointers(&visitor);

    DEBUG_PRINT("relo %p -> %p [%p]\n", address, target_address,
                address - space_base_ + rebase_base_);
    return from->Size();
  }

 private:
  friend class PointerRebasingVisitor;

  uword space_base_;
  uword target_base_;
  uword rebase_base_;
};

int ProgramHeapRelocator::Relocate() {
  // Clear away the intrinsics as they will point to the wrong
  // addresses.
  program_->ClearDispatchTableIntrinsics();
  // And then setup fresh ones using our relocation table.
  program_->SetupDispatchTableIntrinsics(table_, method_entry_);

  // Make sure we only have one chunk in the heap so that we can linearly
  // relocate objects to the new base.
  SemiSpace* space = program_->heap()->space();
  if (space->first() == NULL || space->first() != space->last()) {
    FATAL("We have more chunks than supported. Go fix the runtime!\n");
  }

  DEBUG_PRINT("Relocating %p to %lx\n", program_, baseaddress_);

  Chunk* chunk = space->first();
  int heap_size = chunk->limit() - chunk->base();

  // heap + roots + main_arity
  int total_size = heap_size + sizeof(ProgramInfoBlock);
  memcpy(reinterpret_cast<void*>(target_),
         reinterpret_cast<void*>(chunk->base()), heap_size);
  uword target_base = reinterpret_cast<uword>(target_);

  RelocationVisitor relocator(chunk->base(), target_base, baseaddress_);

  program_->heap()->space()->IterateObjects(&relocator);

  DEBUG_PRINT("Creating program with relocated roots...\n");

  ASSERT(program_->session() == NULL);

  // Create a shadow copy of the program.
  Program* target_program = reinterpret_cast<Program*>(malloc(sizeof(Program)));
  memcpy(reinterpret_cast<void*>(target_program),
         reinterpret_cast<void*>(program_), sizeof(Program));

  // Now fix up root pointers in the copy.
  PointerRebasingVisitor visitor(reinterpret_cast<uword>(program_),
                                 reinterpret_cast<uword>(target_program),
                                 chunk->base(), baseaddress_);
  program_->IterateRoots(&visitor);

  DEBUG_PRINT("Writing relocated roots to info block...\n");

  // And write them to the end of the blob.
  // TODO(herhut): Use placement new here once supported by all toolchains.
  ProgramInfoBlock* program_info =
      reinterpret_cast<ProgramInfoBlock*>(target_ + heap_size);
  program_info->PopulateFromProgram(target_program);

  free(target_program);

  DEBUG_PRINT("Relocation complete, result is %d bytes...\n", target.length());

  return total_size;
}

}  // namespace dartino
