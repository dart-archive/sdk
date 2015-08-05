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
      unmerged_parts_(),
      ticks_(0) {
}

ImmutableHeap::~ImmutableHeap() {
  delete heap_mutex_;

  while (HasUnmergedParts()) {
    Heap* heap = RemoveUnmergedPart();
    delete heap;
  }
}

void ImmutableHeap::AddUnmergedPart(Heap* heap) {
  unmerged_parts_ = new HeapPart(unmerged_parts_);
  unmerged_parts_->heap_part = heap;
}

Heap* ImmutableHeap::RemoveUnmergedPart() {
  HeapPart* part = unmerged_parts_;
  if (part == NULL) return NULL;

  Heap* heap = part->heap_part;
  unmerged_parts_ = part->next;
  delete part;
  return heap;
}

void ImmutableHeap::MergeParts() {
  ScopedLock locker(heap_mutex_);

  ASSERT(outstanding_parts_ == 0);
  while (HasUnmergedParts()) {
    Heap* heap_part = RemoveUnmergedPart();
    heap_.MergeInOtherHeap(heap_part);
    delete heap_part;
  }

  ticks_ = 0;
}

void ImmutableHeap::IterateProgramPointers(PointerVisitor* visitor) {
  ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);

  HeapObjectPointerVisitor heap_pointer_visitor(visitor);
  heap_.IterateObjects(&heap_pointer_visitor);
}

Heap* ImmutableHeap::AcquirePart() {
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

  Heap* part;
  if (HasUnmergedParts()) {
    part = RemoveUnmergedPart();
    part->space()->SetAllocationBudget(budget);
  } else {
    part = new Heap(NULL, budget);
  }

  outstanding_parts_++;
  return part;
}

bool ImmutableHeap::ReleasePart(Heap* part) {
  ScopedLock locker(heap_mutex_);
  ASSERT(outstanding_parts_ > 0);
  outstanding_parts_--;

  part->Flush();
  part->AdjustAllocationBudget();
  AddUnmergedPart(part);

  return ticks_++ == number_of_hw_threads_;
}

}  // namespace fletch
