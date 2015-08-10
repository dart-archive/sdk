// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_IMMUTABLE_HEAP_H_
#define SRC_VM_IMMUTABLE_HEAP_H_

#include "src/shared/globals.h"
#include "src/vm/heap.h"

namespace fletch {

class ImmutableHeap {
 public:
  class Part {
   public:
    Part(Part* next, int budget)
        : heap_(NULL, budget), used_original_(0), next_(next) {}

    Heap* heap() { return &heap_; }

    int Used() { return used_original_; }
    void ResetUsed() { used_original_ = heap_.space()->Used(); }

    int NewlyAllocated() { return heap_.space()->Used() - Used(); }

    Part* next() { return next_; }
    void set_next(Part* next) { next_ = next; }

   private:
    Heap heap_;
    int used_original_;
    Part* next_;
  };

  ImmutableHeap();
  ~ImmutableHeap();

  // Will return a [Heap] which will have an allocation budget which is
  // `known_live_memory / number_of_hw_threads_`. This is an approximation of a
  // 2x growth strategy.
  //
  // TODO(kustermann): instead of `number_of_hw_threads_` we could make this
  // better by keeping track of the current number of used scheduler threads.
  Part* AcquirePart();

  // Will return `true` if the caller should trigger an immutable GC.
  //
  // It is assumed that this function is only called on allocation failures.
  bool ReleasePart(Part* part);

  // Merges all parts which have been acquired and subsequently released into
  // the accumulated immutable heap.
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

 private:
  bool HasUnmergedParts() { return unmerged_parts_ != NULL; }
  void AddUnmergedPart(Part* part);
  Part* RemoveUnmergedPart();

  int ImmutableAllocationLimit();

  int number_of_hw_threads_;

  Mutex* heap_mutex_;
  Heap heap_;
  int outstanding_parts_;
  Part* unmerged_parts_;

  // The amount of memory consumed by outstanding parts/unmerged parts.
  int consumed_memory_;
};

}  // namespace fletch


#endif  // SRC_VM_IMMUTABLE_HEAP_H_
