// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/shared_heap.h"
#include "src/vm/object_memory.h"
#include "src/vm/mark_sweep.h"

namespace fletch {

#ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

SharedHeap::SharedHeap()
    : number_of_hw_threads_(Platform::GetNumberOfHardwareThreads()),
      heap_mutex_(Platform::CreateMutex()),
      heap_(new Space(), reinterpret_cast<WeakPointer*>(NULL)),
      outstanding_parts_(0),
      unmerged_parts_(NULL),
      allocation_limit_(0),
      unmerged_allocated_(0),
      outstanding_parts_allocated_(0),
      outstanding_parts_budget_(0) {
  UpdateLimitAfterGC(0);
}

SharedHeap::~SharedHeap() {
  delete heap_mutex_;

  while (HasUnmergedParts()) {
    delete RemoveUnmergedPart();
  }
}

void SharedHeap::AddUnmergedPart(Part* part) {
  part->set_next(unmerged_parts_);
  unmerged_parts_ = part;
}

SharedHeap::Part* SharedHeap::RemoveUnmergedPart() {
  Part* part = unmerged_parts_;
  if (part == NULL) return NULL;

  unmerged_parts_ = part->next();
  part->set_next(NULL);
  return part;
}

void SharedHeap::UpdateLimitAfterGC(int mutable_size_at_last_gc) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  // Without knowing anything, we use the default [Space] size.
  int limit = number_of_hw_threads_ * Space::kDefaultMinimumChunkSize;

  // If we know the size of what survived during the last immutable GC we
  // make sure the limit is at least that high - thereby making this a 2x
  // growth strategy.
  Space* merged_space = heap_.space();
  if (merged_space != NULL && !merged_space->is_empty()) {
    limit = Utils::Maximum(limit, heap_.UsedTotal());
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
  allocation_limit_ = Utils::Maximum(limit, mutable_size_at_last_gc / 10);
}

int SharedHeap::EstimatedUsed() {
  ScopedLock locker(heap_mutex_);

  int merged_used = heap_.UsedTotal();

  int unmerged_used = 0;
  Part* current = unmerged_parts_;
  while (current != NULL) {
    unmerged_used += current->heap()->UsedTotal();
    current = current->next();
  }

  // This overapproximates used memory of outstanding parts.
  int outstanding_used =
      outstanding_parts_allocated_ + outstanding_parts_budget_;

  return merged_used + unmerged_used + outstanding_used;
}

int SharedHeap::EstimatedSize() {
  ScopedLock locker(heap_mutex_);

  int merged_size = heap_.space()->Size();

  int unmerged_size = 0;
  Part* current = unmerged_parts_;
  while (current != NULL) {
    unmerged_size += current->heap()->space()->Size();
    current = current->next();
  }

  // This overapproximates used memory of outstanding parts.
  int outstanding_size =
      outstanding_parts_allocated_ + outstanding_parts_budget_;

  return merged_size + unmerged_size + outstanding_size;
}

void SharedHeap::MergeParts() {
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

void SharedHeap::IterateProgramPointers(PointerVisitor* visitor) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  HeapObjectPointerVisitor heap_pointer_visitor(visitor);
  heap_.IterateObjects(&heap_pointer_visitor);
}

SharedHeap::Part* SharedHeap::AcquirePart() {
  ScopedLock locker(heap_mutex_);

  int budget = allocation_limit_ / number_of_hw_threads_;

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

bool SharedHeap::ReleasePart(Part* part) {
  ScopedLock locker(heap_mutex_);
  ASSERT(outstanding_parts_ > 0);
  outstanding_parts_--;

  part->heap()->Flush();

  int limit = allocation_limit_;
  int diff = part->NewlyAllocated();
  ASSERT(diff >= 0);
  int new_allocated_memory = unmerged_allocated_ + diff;
  bool gc = unmerged_allocated_ < limit && limit <= new_allocated_memory;
  unmerged_allocated_ = new_allocated_memory;

  outstanding_parts_allocated_ -= part->used();
  outstanding_parts_budget_ -= part->budget();
  AddUnmergedPart(part);

  return gc;
}

#else  // #ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

void SharedHeap::IterateProgramPointers(PointerVisitor* visitor) {
  HeapObjectPointerVisitor heap_pointer_visitor(visitor);
  heap_.IterateObjects(&heap_pointer_visitor);
}

#endif  // #ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

}  // namespace fletch
