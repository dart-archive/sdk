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

#include "src/shared/flags.h"
#include "src/shared/utils.h"
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
  if (result == 0) allocation_budget_ = 0;  // Trigger GC soon.
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

void OldSpace::VisitRememberedSet(GenerationalScavengeVisitor* visitor) {
  Flush();
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    // Scan the byte-map for cards that may have new-space pointers.
    uword current = chunk->base();
    uword bytes =
        reinterpret_cast<uword>(GCMetadata::RememberedSetFor(current));
    uword earliest_iteration_start = current;
    while (current < chunk->limit()) {
      if (Utils::IsAligned(bytes, sizeof(uword))) {
        uword* words = reinterpret_cast<uword*>(bytes);
        // Skip blank cards n at a time.
        ASSERT(GCMetadata::kNoNewSpacePointers == 0);
        if (*words == 0) {
          do {
            bytes += sizeof *words;
            words++;
            current += sizeof(*words) * GCMetadata::kCardSize;
          } while (current < chunk->limit() && *words == 0);
          continue;
        }
      }
      uint8* byte = reinterpret_cast<uint8*>(bytes);
      if (*byte != GCMetadata::kNoNewSpacePointers) {
        uint8* starts = GCMetadata::StartsFor(current);
        // Since there is a dirty object starting in this card, we would like
        // to assert that there is an object starting in this card.
        // Unfortunately, the sweeper does not clean the dirty object bytes,
        // and we don't want to slow down the sweeper, so we cannot make this
        // assertion in the case where a dirty object died and was made into
        // free-list.
        uword iteration_start = current;
        if (starts != GCMetadata::StartsFor(chunk->base())) {
          // If we are not at the start of the chunk, step back into previous
          // card to find a place to start iterating from that is guaranteed to
          // be before the start of the card.  We have to do this because the
          // starts-table can contain the start offset of any object in the
          // card, including objects that have higher addresses than the one(s)
          // with new-space pointers in them.
          do {
            starts--;
            iteration_start -= GCMetadata::kCardSize;
            // Step back across object-start entries that have not been filled
            // in
            // (because of large objects).
          } while (iteration_start > earliest_iteration_start &&
                   *starts == GCMetadata::kNoObjectStart);

          if (iteration_start > earliest_iteration_start) {
            uint8 iteration_low_byte = static_cast<uint8>(iteration_start);
            iteration_start -= iteration_low_byte;
            iteration_start += *starts;
          } else {
            // Do not step back to before the end of an object that we already
            // scanned. This is both for efficiency, and also to avoid backing
            // into a PromotedTrack object, which contains newly allocated
            // objects inside it, which are not yet traversable.
            iteration_start = earliest_iteration_start;
          }
        }
        // Skip objects that start in the previous card.
        while (iteration_start < current) {
          if (HasSentinelAt(iteration_start)) break;
          HeapObject* object = HeapObject::FromAddress(iteration_start);
          iteration_start += object->Size();
        }
        // Reset in case there are no new-space pointers any more.
        *byte = GCMetadata::kNoNewSpacePointers;
        visitor->set_record_new_space_pointers(byte);
        // Iterate objects that start in the relevant card.
        while (iteration_start < current + GCMetadata::kCardSize) {
          if (HasSentinelAt(iteration_start)) break;
          HeapObject* object = HeapObject::FromAddress(iteration_start);
          object->IteratePointers(visitor);
          iteration_start += object->Size();
        }
        earliest_iteration_start = iteration_start;
      }
      current += GCMetadata::kCardSize;
      bytes++;
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
bool OldSpace::CompleteScavengeGenerational(
    GenerationalScavengeVisitor* visitor) {
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
      visitor->set_record_new_space_pointers(
          GCMetadata::RememberedSetFor(obj->address()));
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

void SweepingVisitor::AddFreeListChunk(uword free_end) {
  if (free_start_ != 0) {
    uword free_size = free_end - free_start_;
    // When sweeping the new space we just remove mark bits, but don't build
    // free lists, since it is GCed by scavenge instead.
    if (free_list_ != NULL) {
      free_list_->AddChunk(free_start_, free_size);
#ifdef DEBUG
    } else if (Flags::validate_heaps) {
      // If we want to be able to verify the new-space we have to put free-list
      // objects in place even if we are not going to collect them in
      // free-lists.
      FreeListChunk::CreateAt(free_start_, free_size);
#endif
    }
    free_start_ = 0;
  }
}

int SweepingVisitor::Visit(HeapObject* object) {
  if (object->IsMarked()) {
    AddFreeListChunk(object->address());
    if (free_list_ != NULL) {
      // Don't bother recording object start offsets for the new space where
      // free_list_ is null.
      GCMetadata::RecordStart(object->address());
    }
    object->ClearMark();
    int size = object->Size();
    used_ += size;
    return size;
  }
  int size = object->Size();
  if (free_start_ == 0) free_start_ = object->address();
  return size;
}

void OldSpace::ProcessWeakPointers() {
  WeakPointer::Process(&weak_pointers_, this);
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
  // Verify that the remembered set table is marked for all objects that
  // contain new-space pointers.
  for (Chunk* chunk = first(); chunk != NULL; chunk = chunk->next()) {
    uword current = chunk->base();
    while (!HasSentinelAt(current)) {
      HeapObject* object = HeapObject::FromAddress(current);
      if (object->ContainsPointersTo(heap_->space())) {
        ASSERT(*GCMetadata::RememberedSetFor(current));
      }
      current += object->Size();
    }
  }
}
#endif

}  // namespace dartino
