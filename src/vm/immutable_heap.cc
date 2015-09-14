// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/immutable_heap.h"
#include "src/vm/object_memory.h"

namespace fletch {

ImmutableHeap::ImmutableHeap()
    : number_of_hw_threads_(Platform::GetNumberOfHardwareThreads()),
      heap_mutex_(Platform::CreateMutex()),
      heap_(new Space(), reinterpret_cast<WeakPointer*>(NULL)),
      outstanding_parts_(0),
      unmerged_parts_(NULL),
      immutable_allocation_limit_(0),
      unmerged_allocated_(0),
      outstanding_parts_allocated_(0),
      outstanding_parts_budget_(0) {
  UpdateLimitAfterImmutableGC(0);
}

ImmutableHeap::~ImmutableHeap() {
  delete heap_mutex_;

  while (HasUnmergedParts()) {
    delete RemoveUnmergedPart();
  }
}

void ImmutableHeap::AddUnmergedPart(Part* part) {
  part->set_next(unmerged_parts_);
  unmerged_parts_ = part;
}

ImmutableHeap::Part* ImmutableHeap::RemoveUnmergedPart() {
  Part* part = unmerged_parts_;
  if (part == NULL) return NULL;

  unmerged_parts_ = part->next();
  part->set_next(NULL);
  return part;
}

void ImmutableHeap::UpdateLimitAfterImmutableGC(uword mutable_size_at_last_gc) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  // Without knowing anything, we use the default [Space] size.
  uword limit = number_of_hw_threads_ * Space::kDefaultMinimumChunkSize;

  // If we know the size of what survived during the last immutable GC we
  // make sure the limit is at least that high - thereby making this a 2x
  // growth strategy.
  Space* merged_space = heap_.space();
  if (merged_space != NULL && !merged_space->is_empty()) {
    limit = Utils::Maximum(limit, merged_space->Used());
  }

  // We introduce a constraint here to allow the size of mutable heaps to guide
  // how large the immutable heap can be. Since the amount of computation for
  // an immutable GC depends on the "root set", which is in turn influenced by
  // the size of mutable heaps. Ignoring this factor can cause a lot of
  // unnecessary immutable GCs and therefore also unnecessary storebuffer
  // compactions.
  //
  // TODO(kustermann): We might want to use a different metric than the mutable
  // heap size (preferable the number of pointers to immutable space - the
  // size of the root set).
  immutable_allocation_limit_ =
      Utils::Maximum(limit, mutable_size_at_last_gc / 10);
}

uword ImmutableHeap::EstimatedUsed() {
  ScopedLock locker(heap_mutex_);

  uword merged_used = heap_.space()->Used();

  uword unmerged_used = 0;
  Part* current = unmerged_parts_;
  while (current != NULL) {
    unmerged_used += current->heap()->space()->Used();
    current = current->next();
  }

  // This overapproximates used memory of outstanding parts.
  uword outstanding_used =
      outstanding_parts_allocated_ + outstanding_parts_budget_;

  return merged_used + unmerged_used + outstanding_used;
}

uword ImmutableHeap::EstimatedSize() {
  ScopedLock locker(heap_mutex_);

  uword merged_size = heap_.space()->Size();

  uword unmerged_size = 0;
  Part* current = unmerged_parts_;
  while (current != NULL) {
    unmerged_size += current->heap()->space()->Size();
    current = current->next();
  }

  // This overapproximates used memory of outstanding parts.
  uword outstanding_size =
      outstanding_parts_allocated_ + outstanding_parts_budget_;

  return merged_size + unmerged_size + outstanding_size;
}

void ImmutableHeap::MergeParts() {
  ScopedLock locker(heap_mutex_);

  ASSERT(outstanding_parts_ == 0);
  ASSERT(outstanding_parts_allocated_ == 0);
  ASSERT(outstanding_parts_budget_ == 0);
  while (HasUnmergedParts()) {
    Part* part = RemoveUnmergedPart();
    heap_.MergeInOtherHeap(part->heap());
    delete part;
  }
  unmerged_allocated_ = 0;
}

void ImmutableHeap::IterateProgramPointers(PointerVisitor* visitor) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  HeapObjectPointerVisitor heap_pointer_visitor(visitor);
  heap_.IterateObjects(&heap_pointer_visitor);
}

ImmutableHeap::Part* ImmutableHeap::AcquirePart() {
  ScopedLock locker(heap_mutex_);

  int budget = immutable_allocation_limit_ / number_of_hw_threads_;

  Part* part;
  if (HasUnmergedParts()) {
    part = RemoveUnmergedPart();
    part->heap()->space()->SetAllocationBudget(budget);
    part->set_budget(budget);
    part->ResetUsed();
  } else {
    part = new Part(NULL, budget);
  }

  outstanding_parts_allocated_ += part->used();
  outstanding_parts_budget_ += part->budget();

  outstanding_parts_++;
  return part;
}

bool ImmutableHeap::ReleasePart(Part* part) {
  ScopedLock locker(heap_mutex_);
  ASSERT(outstanding_parts_ > 0);
  outstanding_parts_--;

  part->heap()->Flush();

  uword limit = immutable_allocation_limit_;
  int diff = part->NewlyAllocated();
  ASSERT(diff >= 0);
  uword new_allocated_memory = unmerged_allocated_ + diff;
  bool gc = unmerged_allocated_ < limit && limit < new_allocated_memory;
  unmerged_allocated_ = new_allocated_memory;

  outstanding_parts_allocated_ -= part->used();
  outstanding_parts_budget_ -= part->budget();
  AddUnmergedPart(part);

  return gc;
}

}  // namespace fletch
