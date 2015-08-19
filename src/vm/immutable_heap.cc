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
      consumed_memory_(0) {
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

void ImmutableHeap::UpdateLimitAfterImmutableGC(int mutable_size_at_last_gc) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  // Without knowing anything, we use the default [Space] size.
  int limit = number_of_hw_threads_ * Space::kDefaultMinimumChunkSize;

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
  // TODO(kustermann): Once we have de-duplication of storebuffer entries, we
  //   * might want to reduce this division factor
  //   * might want to use a different metric than the mutable heap size
  //     (preferable the number of pointers to immutable space - the size of the
  //      root set).
  immutable_allocation_limit_ =
      Utils::Maximum(limit, mutable_size_at_last_gc / 2);
}

void ImmutableHeap::MergeParts() {
  ScopedLock locker(heap_mutex_);

  ASSERT(outstanding_parts_ == 0);
  while (HasUnmergedParts()) {
    Part* part = RemoveUnmergedPart();
    heap_.MergeInOtherHeap(part->heap());
    delete part;
  }
  consumed_memory_ = 0;
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
    part->ResetUsed();
  } else {
    part = new Part(NULL, budget);
  }

  outstanding_parts_++;
  return part;
}

bool ImmutableHeap::ReleasePart(Part* part) {
  ScopedLock locker(heap_mutex_);
  ASSERT(outstanding_parts_ > 0);
  outstanding_parts_--;

  part->heap()->Flush();
  AddUnmergedPart(part);

  int limit = immutable_allocation_limit_;
  int diff = part->NewlyAllocated();
  ASSERT(diff >= 0);
  int new_consumed_memory = consumed_memory_ + diff;
  bool gc = consumed_memory_ < limit && limit < new_consumed_memory;

  consumed_memory_ += diff;
  return gc;
}

}  // namespace fletch
