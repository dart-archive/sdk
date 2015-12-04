// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SHARED_HEAP_H_
#define SRC_VM_SHARED_HEAP_H_

#include "src/shared/globals.h"
#include "src/vm/heap.h"

namespace fletch {

#ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

class SharedHeap {
 public:
  class Part {
   public:
    Part(Part* next, int budget)
        : heap_(NULL, budget),
          budget_(budget),
          used_original_(0),
          next_(next) {}

    Heap* heap() { return &heap_; }

    int budget() { return budget_; }
    void set_budget(int new_budget) { budget_ = new_budget; }

    int used() { return used_original_; }

    void ResetUsed() { used_original_ = heap_.UsedTotal(); }

    int NewlyAllocated() { return heap_.UsedTotal() - used_original_; }

    Part* next() { return next_; }
    void set_next(Part* next) { next_ = next; }

   private:
    Heap heap_;
    int budget_;
    int used_original_;
    Part* next_;
  };

  SharedHeap();
  ~SharedHeap();

  // Will return a [Heap] which will have an allocation budget which is
  // `known_live_memory / number_of_hw_threads_`. This is an approximation of a
  // 2x growth strategy.
  //
  // TODO(kustermann): instead of `number_of_hw_threads_` we could make this
  // better by keeping track of the current number of used scheduler threads.
  Part* AcquirePart();

  // Will return `true` if the caller should trigger a GC.
  //
  // It is assumed that this function is only called on allocation failures.
  bool ReleasePart(Part* part);

  // Merges all parts which have been acquired and subsequently released into
  // the accumulated shared heap.
  //
  // This function assumes that there are no parts outstanding.
  void MergeParts();

  // This method can only be called if
  //   * all acquired parts were released again
  //   * all cached parts were merged via [MergeParts]
  void IterateProgramPointers(PointerVisitor* visitor);

  // This method can only be called if
  //   * all acquired parts were released again
  //   * all cached parts were merged via [MergeParts]
  Heap* heap() {
    ASSERT(outstanding_parts_ == 0 && unmerged_parts_ == NULL);
    return &heap_;
  }

  // This method can only be called if
  //   * all acquired parts were released again
  //   * all cached parts were merged via [MergeParts]
  void UpdateLimitAfterGC(int mutable_size_at_last_gc);

  // The number of used bytes at the moment. Note that this is an over
  // approximation.
  int EstimatedUsed();

  // The total size of the shared heap at the moment. Note that this is an
  // over approximation.
  int EstimatedSize();

 private:
  bool HasUnmergedParts() { return unmerged_parts_ != NULL; }
  void AddUnmergedPart(Part* part);
  Part* RemoveUnmergedPart();

  int number_of_hw_threads_;

  Mutex* heap_mutex_;
  Heap heap_;
  int outstanding_parts_;
  Part* unmerged_parts_;

  // The limit of bytes we give out before a GC should happen.
  int allocation_limit_;

  // The amount of memory consumed by unmerged parts.
  int unmerged_allocated_;

  // The allocated memory and budget of all outstanding parts.
  //
  // Adding these two number gives an overapproximation of used memory by
  // oustanding parts.
  int outstanding_parts_allocated_;
  int outstanding_parts_budget_;
};

#else  // #ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

class SharedHeap {
 public:
  SharedHeap() : heap_(NULL, 4 * KB) {}
  ~SharedHeap() {}

  void MergeParts() {}

  void IterateProgramPointers(PointerVisitor* visitor);

  Heap* heap() { return &heap_; }

  int EstimatedUsed() { return heap_.space()->Used(); }

  int EstimatedSize() { return heap_.space()->Size(); }

 private:
  Heap heap_;
};

#endif  // #ifdef FLETCH_ENABLE_MULTIPLE_PROCESS_HEAPS

}  // namespace fletch

#endif  // SRC_VM_SHARED_HEAP_H_
