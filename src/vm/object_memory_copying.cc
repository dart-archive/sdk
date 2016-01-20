// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object_memory.h"

#include "src/vm/object.h"

namespace fletch {

static Smi* chunk_end_sentinel() { return Smi::zero(); }

Space::Space(int maximum_initial_size)
    : first_(NULL),
      last_(NULL),
      used_(0),
      top_(0),
      limit_(0),
      no_allocation_nesting_(0) {
  if (maximum_initial_size > 0) {
    int size = Utils::Minimum(maximum_initial_size, kDefaultMaximumChunkSize);
    Chunk* chunk = ObjectMemory::AllocateChunk(this, size);
    if (chunk == NULL) FATAL1("Failed to allocate %d bytes.\n", size);
    Append(chunk);
    top_ = chunk->base();
    limit_ = chunk->limit();
  }
}

void SemiSpace::Flush() {
  if (!is_empty()) {
    // Set sentinel at allocation end.
    ASSERT(top_ < limit_);
    *reinterpret_cast<Object**>(top_) = chunk_end_sentinel();
  }
}

HeapObject* SemiSpace::NewLocation(HeapObject* old_location) {
  ASSERT(Includes(old_location->address()));
  return old_location->forwarding_address();
}

bool SemiSpace::IsAlive(HeapObject* old_location) {
  ASSERT(Includes(old_location->address()));
  return old_location->HasForwardingAddress();
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

void SemiSpace::Append(Chunk* chunk) {
  if (!is_empty()) {
    // Update the accounting.
    used_ += top() - last()->base();
  }
  Space::Append(chunk);
}

void SemiSpace::SetAllocationPointForPrepend(SemiSpace* space) {
  // If the current space is empty, continue allocation in the
  // last chunk of the prepended space.
  if (is_empty()) {
    last_ = space->last();
    top_ = space->top_;
    limit_ = space->limit_;
  }
}

uword SemiSpace::TryAllocate(int size) {
  uword new_top = top_ + size;
  // Make sure there is room for chunk end sentinel.
  if (new_top < limit_) {
    uword result = top_;
    top_ = new_top;
    return result;
  }

  if (!is_empty()) {
    // Make the last chunk consistent with a sentinel.
    Flush();
  }

  return 0;
}

uword SemiSpace::AllocateInNewChunk(int size, bool fatal) {
  // Allocate new chunk that is big enough to fit the object.
  int default_chunk_size = DefaultChunkSize(Used());
  int chunk_size =
      size >= default_chunk_size
          ? (size + kPointerSize)  // Make sure there is room for sentinel.
          : default_chunk_size;

  Chunk* chunk = ObjectMemory::AllocateChunk(this, chunk_size);
  if (chunk != NULL) {
    // Link it into the space.
    Append(chunk);

    // Update limits.
    allocation_budget_ -= chunk->size();
    top_ = chunk->base();
    limit_ = chunk->limit();

    // Allocate.
    uword result = TryAllocate(size);
    if (result != 0) return result;
  }
  if (fatal) FATAL1("Failed to allocate memory of size %d\n", size);
  return 0;
}

uword SemiSpace::AllocateInternal(int size, bool fatal) {
  ASSERT(size >= HeapObject::kSize);
  ASSERT(Utils::IsAligned(size, kPointerSize));
  if (!in_no_allocation_failure_scope() && needs_garbage_collection()) {
    return 0;
  }

  uword result = TryAllocate(size);
  if (result != 0) return result;

  return AllocateInNewChunk(size, fatal);
}

void SemiSpace::TryDealloc(uword location, int size) {
  if (top_ == location) top_ -= size;
}

int SemiSpace::Used() {
  if (is_empty()) return used_;
  return used_ + (top() - last()->base());
}

}  // namespace fletch
