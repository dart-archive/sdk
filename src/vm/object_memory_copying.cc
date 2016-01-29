// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object_memory.h"

#include "src/vm/object.h"

namespace fletch {

// In the semispaces, the sentinel marks the allocation limit in each chunk.
// It is written when we flush, and when we allocate during GC, but it is not
// necessarily maintained when allocating between GCs.
static Smi* chunk_end_sentinel() { return Smi::zero(); }

static bool HasSentinelAt(uword address) {
  return *reinterpret_cast<Object**>(address) == chunk_end_sentinel();
}

static void WriteSentinelAt(uword address) {
  *reinterpret_cast<Object**>(address) = chunk_end_sentinel();
}

Space::Space(int maximum_initial_size)
    : first_(NULL),
      last_(NULL),
      used_(0),
      top_(0),
      limit_(0),
      no_allocation_nesting_(0) {}

SemiSpace::SemiSpace(int maximum_initial_size) : Space(maximum_initial_size) {
  if (maximum_initial_size > 0) {
    int size = Utils::Minimum(maximum_initial_size, kDefaultMaximumChunkSize);
    Chunk* chunk = ObjectMemory::AllocateChunk(this, size);
    if (chunk == NULL) FATAL1("Failed to allocate %d bytes.\n", size);
    Append(chunk);
    UpdateBaseAndLimit(chunk, chunk->base());
  }
}

bool SemiSpace::IsFlushed() {
  if (top_ == 0 && limit_ == 0) return true;
  return HasSentinelAt(top_);
}

void SemiSpace::UpdateBaseAndLimit(Chunk* chunk, uword top) {
  ASSERT(IsFlushed());
  ASSERT(top >= chunk->base());
  ASSERT(top < chunk->limit());

  top_ = top;
  // Always write a sentinel so the scavenger knows where to stop.
  WriteSentinelAt(top_);
  limit_ = chunk->limit();
}

void SemiSpace::Flush() {
  if (!is_empty()) {
    // Set sentinel at allocation end.
    ASSERT(top_ < limit_);
    WriteSentinelAt(top_);
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

uword SemiSpace::TryAllocate(int size) {
  uword new_top = top_ + size;
  // Make sure there is room for chunk end sentinel.
  if (new_top < limit_) {
    uword result = top_;
    top_ = new_top;
    // Always write a sentinel so the scavenger knows where to stop.
    WriteSentinelAt(top_);
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
    UpdateBaseAndLimit(chunk, chunk->base());

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

// Called multiple times until there is no more work.  Finds objects moved to
// the to-space and traverses them to find and fix more new-space pointers.
bool SemiSpace::CompleteScavengeGenerational(PointerVisitor* visitor) {
  bool found_work = false;

  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->scavenge_pointer();
    while (!HasSentinelAt(current)) {
      found_work = true;
      HeapObject* object = HeapObject::FromAddress(current);
      object->IteratePointers(visitor);

      current += object->Size();
    }
    // Set up the already-scanned pointer for next round.
    chunk->set_scavenge_pointer(current);
  }

  return found_work;
}

}  // namespace fletch
