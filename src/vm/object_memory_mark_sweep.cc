// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
// Mark-sweep old-space.
// * Uses worst-fit free-list allocation to get big chunks for fast bump
//   allocation.
// * Non-moving for now.
// * Has on-heap chained data structure keeping track of
//   promoted-and-not-yet-scanned areas.  This is called PromotedTrack.
// * No remembered set yet.  When scavenging we have to scan all of old space.
//   We skip PromotedTrack areas because we know we will get to them later and
//   they contain uninitialized memory.

#include "src/vm/mark_sweep.h"
#include "src/vm/object_memory.h"
#include "src/vm/object.h"

namespace dartino {

// In oldspace, the sentinel marks the end of each chunk, and never moves or is
// overwritten.
static Smi* chunk_end_sentinel() { return Smi::zero(); }

static bool HasSentinelAt(uword address) {
  return *reinterpret_cast<Object**>(address) == chunk_end_sentinel();
}

OldSpace::OldSpace(TwoSpaceHeap* owner)
    : Space(kCanResize),
      heap_(owner),
      free_list_(new FreeList()),
      tracking_allocations_(false),
      promoted_track_(NULL) {}

OldSpace::~OldSpace() { delete free_list_; }

void OldSpace::Flush() {
  if (top_ != 0) {
    uword free_size = limit_ - top_;
    free_list_->AddChunk(top_, free_size);
    if (tracking_allocations_ && promoted_track_ != NULL) {
      // The latest promoted_track_ entry is set to cover the entire
      // current allocation area, so that we skip it when traversing the
      // stack.  Reset it to cover only the bit we actually used.
      ASSERT(promoted_track_ != NULL);
      ASSERT(promoted_track_->end() >= top_);
      promoted_track_->set_end(top_);
    }
    top_ = 0;
    limit_ = 0;
    used_ -= free_size;
    ASSERT(used_ >= 0);
  }
}

HeapObject* OldSpace::NewLocation(HeapObject* old_location) {
  ASSERT(Includes(old_location->address()));
  ASSERT(old_location->IsMarked());
  return old_location;
}

bool OldSpace::IsAlive(HeapObject* old_location) {
  ASSERT(Includes(old_location->address()));
  return old_location->IsMarked();
}

void OldSpace::UseWholeChunk(Chunk* chunk) {
  top_ = chunk->base();
  limit_ = top_ + chunk->size() - kPointerSize;
  *reinterpret_cast<Object**>(limit_) = chunk_end_sentinel();
  if (tracking_allocations_) {
    promoted_track_ = PromotedTrack::Initialize(promoted_track_, top_, limit_);
    top_ += PromotedTrack::kHeaderSize;
  }
  // Account all of the chunk memory as used for now. When the
  // rest of the freelist chunk is flushed into the freelist we
  // decrement used_ by the amount still left unused. used_
  // therefore reflects actual memory usage after Flush has been
  // called.
  used_ += chunk->size() - kPointerSize;
}

Chunk* OldSpace::AllocateAndUseChunk(int size) {
  Chunk* chunk = ObjectMemory::AllocateChunk(this, size);
  if (chunk != NULL) {
    // Link it into the space.
    Append(chunk);
    UseWholeChunk(chunk);
    GCMetadata::InitializeStartsForChunk(chunk);
    GCMetadata::InitializeRememberedSetForChunk(chunk);
  }
  return chunk;
}

uword OldSpace::AllocateInNewChunk(int size) {
  ASSERT(top_ == 0);  // Space is flushed.
  // Allocate new chunk that is big enough to fit the object.
  int tracking_size = tracking_allocations_ ? 0 : PromotedTrack::kHeaderSize;
  int default_chunk_size = DefaultChunkSize(Used());
  int chunk_size =
      (size + tracking_size + kPointerSize >= default_chunk_size)
          ? (size + tracking_size + kPointerSize)  // Make room for sentinel.
          : default_chunk_size;

  Chunk* chunk = AllocateAndUseChunk(chunk_size);
  if (chunk != NULL) {
    return Allocate(size);
  }

  allocation_budget_ = -1;  // Trigger GC.
  return 0;
}

uword OldSpace::AllocateFromFreeList(int size) {
  // Flush the rest of the active chunk into the free list.
  Flush();

  FreeListChunk* chunk = free_list_->GetChunk(
      tracking_allocations_ ? size + PromotedTrack::kHeaderSize : size);
  if (chunk != NULL) {
    top_ = chunk->address();
    limit_ = top_ + chunk->size();
    // Account all of the chunk memory as used for now. When the
    // rest of the freelist chunk is flushed into the freelist we
    // decrement used_ by the amount still left unused. used_
    // therefore reflects actual memory usage after Flush has been
    // called.  (Do this before the tracking info below overwrites
    // the free chunk's data.)
    used_ += chunk->size();
    if (tracking_allocations_) {
      promoted_track_ =
          PromotedTrack::Initialize(promoted_track_, top_, limit_);
      top_ += PromotedTrack::kHeaderSize;
    }
    ASSERT(static_cast<unsigned>(size) <= limit_ - top_);
    return Allocate(size);
  }

  return 0;
}

uword OldSpace::Allocate(int size) {
  ASSERT(size >= HeapObject::kSize);
  ASSERT(Utils::IsAligned(size, kPointerSize));

  // Fast case bump allocation.
  if (limit_ - top_ >= static_cast<uword>(size)) {
    uword result = top_;
    top_ += size;
    allocation_budget_ -= size;
    GCMetadata::RecordStart(result);
    return result;
  }

  if (!in_no_allocation_failure_scope() && needs_garbage_collection()) {
    return 0;
  }

  // Can't use bump allocation. Allocate from free lists.
  uword result = AllocateFromFreeList(size);
  if (result == 0) result = AllocateInNewChunk(size);
  return result;
}

int OldSpace::Used() { return used_; }

void OldSpace::StartTrackingAllocations() {
  Flush();
  ASSERT(!tracking_allocations_);
  ASSERT(promoted_track_ == NULL);
  tracking_allocations_ = true;
}

void OldSpace::EndTrackingAllocations() {
  ASSERT(tracking_allocations_);
  ASSERT(promoted_track_ == NULL);
  tracking_allocations_ = false;
}

// Currently there is no remembered set, so we scan the entire old space,
// skipping only the areas where newly promoted objects are.
void OldSpace::VisitRememberedSet(PointerVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      // Newly promoted objects are automatically skipped, because they
      // are protected by a PromotedTrack object.
      InstanceFormat format = object->IteratePointers(visitor);
      if (!format.has_variable_part()) {
        current += format.fixed_size();
      } else {
        current += object->Size();
      }
    }
  }
}

void OldSpace::UnlinkPromotedTrack() {
  PromotedTrack* promoted = promoted_track_;
  promoted_track_ = NULL;

  while (promoted) {
    PromotedTrack* previous = promoted;
    promoted = promoted->next();
    previous->Zap(StaticClassStructures::one_word_filler_class());
  }
}

// Called multiple times until there is no more work.  Finds objects moved to
// the old-space and traverses them to find and fix more new-space pointers.
bool OldSpace::CompleteScavengeGenerational(PointerVisitor* visitor) {
  Flush();
  ASSERT(tracking_allocations_);

  bool found_work = false;
  PromotedTrack* promoted = promoted_track_;
  // Unlink the promoted tracking list.  Any new promotions go on a new chain,
  // from now on, which will be handled in the next round.
  promoted_track_ = NULL;

  while (promoted) {
    uword traverse = promoted->start();
    uword end = promoted->end();
    if (traverse != end) {
      found_work = true;
    }
    for (HeapObject *obj = HeapObject::FromAddress(traverse); traverse != end;
         traverse += obj->Size(), obj = HeapObject::FromAddress(traverse)) {
      obj->IteratePointers(visitor);
    }
    PromotedTrack* previous = promoted;
    promoted = promoted->next();
    previous->Zap(StaticClassStructures::one_word_filler_class());
  }
  return found_work;
}

SweepingVisitor::SweepingVisitor(OldSpace* space)
    : free_list_(space == NULL ? NULL : space->free_list()),
      free_start_(0),
      used_(0) {
  // Clear the free list. It will be rebuilt during sweeping.
  if (free_list_ != NULL) free_list_->Clear();
}

#ifdef DEBUG
void OldSpace::Verify() {
  // Verify that the object starts table contains only legitimate object start
  // addresses for each chunk in the space.
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword base = chunk->base();
    uword limit = chunk->limit();
    uint8* starts = GCMetadata::StartsFor(base);
    for (uword card = base; card < limit;
         card += GCMetadata::kCardSize, starts++) {
      if (*starts == GCMetadata::kNoObjectStart) continue;
      // Replace low byte of card address with the byte from the object starts
      // table, yielding some correct object start address.
      uword object_address = (card & ~0xff) | *starts;
      ASSERT(object_address >> GCMetadata::kCardBits ==
             card >> GCMetadata::kCardBits);
      HeapObject* obj = HeapObject::FromAddress(object_address);
      ASSERT(obj->get_class()->IsClass());
      ASSERT(obj->Size() > 0);
      if (object_address + obj->Size() > card + 2 * GCMetadata::kCardSize) {
        // If this object stretches over the whole of the next card then the
        // next entry in the object starts table must be invalid.
        ASSERT(starts[1] == GCMetadata::kNoObjectStart);
      }
    }
  }
}
#endif

}  // namespace dartino
