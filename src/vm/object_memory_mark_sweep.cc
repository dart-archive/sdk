// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_MARK_SWEEP

#include "src/vm/object_memory.h"

#include "src/vm/mark_sweep.h"
#include "src/vm/object.h"

namespace fletch {

static Smi* chunk_end_sentinel() { return Smi::zero(); }

static bool HasSentinelAt(uword address) {
  return *reinterpret_cast<Object**>(address) == chunk_end_sentinel();
}

Space::Space(int maximum_initial_size)
    : first_(NULL),
      last_(NULL),
      used_(0),
      top_(0),
      limit_(0),
      no_allocation_nesting_(0),
      free_list_(new FreeList()) {
  if (maximum_initial_size > 0) {
    int size = Utils::Minimum(maximum_initial_size, kDefaultMaximumChunkSize);
    Chunk* chunk = ObjectMemory::AllocateChunk(this, size);
    if (chunk == NULL) FATAL1("Failed to allocate %d bytes.\n", size);
    Append(chunk);
    uword last_word = first()->base() + first()->size() - kPointerSize;
    *reinterpret_cast<Object**>(last_word) = chunk_end_sentinel();
    top_ = first()->base();
    limit_ = last_word;
    used_ += first()->size() - kPointerSize;
  }
}

Space::~Space() {
  delete free_list_;
  FreeAllChunks();
}

void Space::Flush() {
  if (top_ != 0) {
    uword free_size = limit_ - top_;
    free_list_->AddChunk(top_, free_size);
    top_ = 0;
    limit_ = 0;
    used_ -= free_size;
  }
}

void Space::Append(Chunk* chunk) {
  ASSERT(chunk->owner() == this);
  if (is_empty()) {
    first_ = last_ = chunk;
  } else {
    last_->set_next(chunk);
    last_ = chunk;
  }
  chunk->set_next(NULL);
}

void Space::SetAllocationPointForPrepend(Space* space) {
  free_list_->Merge(space->free_list_);
}

uword Space::AllocateInNewChunk(int size, bool fatal) {
  // Allocate new chunk that is big enough to fit the object.
  int default_chunk_size = DefaultChunkSize(Used());
  int chunk_size = (size >= default_chunk_size)
      ? (size + kPointerSize)  // Make sure there is room for sentinel.
      : default_chunk_size;

  Chunk* chunk = ObjectMemory::AllocateChunk(this, chunk_size);
  if (chunk != NULL) {
    // Link it into the space.
    Append(chunk);
    uword last_word = chunk->base() + chunk->size() - kPointerSize;
    *reinterpret_cast<Object**>(last_word) = chunk_end_sentinel();
    top_ = chunk->base();
    limit_ = last_word;
    // Account all of the chunk memory as used for now. When the
    // rest of the freelist chunk is flushed into the freelist we
    // decrement used_ by the amount still left unused. used_
    // therefore reflects actual memory usage after Flush has been
    // called.
    used_ += chunk->size() - kPointerSize;
    return AllocateLinearly(size);
  }

  if (fatal) FATAL1("Failed to allocate memory of size %d\n", size);
  return 0;
}

uword Space::AllocateLinearly(int size) {
  // Fast case bump allocation.
  if (limit_ - top_ >= static_cast<uword>(size)) {
    uword result = top_;
    top_ += size;
    allocation_budget_ -= size;
    *reinterpret_cast<Object**>(top_) = chunk_end_sentinel();
    return result;
  }

  Flush();

  return AllocateInNewChunk(size, true);
}

uword Space::AllocateFromFreeList(int size, bool fatal) {
  // Flush the active chunk into the free list.
  Flush();

  FreeListChunk* chunk = free_list_->GetChunk(size);
  if (chunk != NULL) {
    top_ = chunk->address();
    limit_ = chunk->address() + chunk->size();
    // Account all of the chunk memory as used for now. When the
    // rest of the freelist chunk is flushed into the freelist we
    // decrement used_ by the amount still left unused. used_
    // therefore reflects actual memory usage after Flush has been
    // called.
    used_ += chunk->size();
    return Allocate(size);
  } else {
    return AllocateInNewChunk(size, fatal);
  }

  if (fatal) FATAL1("Failed to allocate memory of size %d\n", size);
  return 0;
}

uword Space::AllocateInternal(int size, bool fatal) {
  ASSERT(size >= HeapObject::kSize);
  ASSERT(Utils::IsAligned(size, kPointerSize));
  if (!in_no_allocation_failure_scope() && needs_garbage_collection()) {
    return 0;
  }

  // Fast case bump allocation.
  if (limit_ - top_ >= static_cast<uword>(size)) {
    uword result = top_;
    top_ += size;
    allocation_budget_ -= size;
    return result;
  }

  // Can't use bump allocation. Allocate from free lists.
  return AllocateFromFreeList(size, fatal);
}

void Space::TryDealloc(uword location, int size) {
  if (top_ == location) {
    top_ -= size;
    allocation_budget_ += size;
  }
}

int Space::Used() {
  return used_;
}

void Space::RebuildFreeListAfterTransformations() {
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword free_start = 0;
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->forwarding_address() != NULL) {
        if (free_start == 0) free_start = current;
        current += Instance::kSize;
        while (*reinterpret_cast<uword*>(current) == HeapObject::kTag) {
          current += kPointerSize;
        }
      } else {
        if (free_start != 0) {
          free_list_->AddChunk(free_start, current - free_start);
          free_start = 0;
        }
        current += object->Size();
      }
    }
  }
}

}  // namespace fletch

#endif  // #ifdef FLETCH_MARK_SWEP
