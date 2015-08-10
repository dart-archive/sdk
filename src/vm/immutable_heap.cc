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
      consumed_memory_(0) {
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

int ImmutableHeap::ImmutableAllocationLimit() {
  return Utils::Maximum(
      number_of_hw_threads_ * Space::kDefaultChunkSize,
      heap_.space()->Used());
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

  // Calculate new allocation budget we want to give out.
  Space* merged_space = heap_.space();
  int size = 0;
  if (merged_space != NULL && !merged_space->is_empty()) {
    // We allow each thread to get the amount of live memory per
    // thread (i.e. a "2x of live memory" heap size strategy).
    size = merged_space->Used() / number_of_hw_threads_;
  }
  int budget = Utils::Maximum(size, Space::kDefaultChunkSize);

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

  int limit = ImmutableAllocationLimit();
  int diff = part->NewlyAllocated();
  ASSERT(diff >= 0);
  int new_consumed_memory = consumed_memory_ + diff;
  bool gc = consumed_memory_ < limit && limit < new_consumed_memory;
  consumed_memory_ += diff;
  return gc;
}

}  // namespace fletch
