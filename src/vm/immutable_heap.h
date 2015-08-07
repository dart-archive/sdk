// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_IMMUTABLE_HEAP_H_
#define SRC_VM_IMMUTABLE_HEAP_H_

#include "src/shared/globals.h"
#include "src/vm/heap.h"

namespace fletch {

// TODO(kustermann): The current tick based mechanism for determining when a GC
// should happen is a little bit fragile. We should take the exact number of
// newly allocated bytes into account.
class ImmutableHeap {
 public:
  ImmutableHeap();
  ~ImmutableHeap();

  // Will return a [Heap] which will have an allocation budget which is
  // `known_live_memory / number_of_hw_threads_`. This is an approximation of a
  // 2x growth strategy.
  //
  // TODO(kustermann): instead of `number_of_hw_threads_` we could make this
  // better by keeping track of the current number of used scheduler threads.
  Heap* AcquirePart();

  // Will return `true` if the caller should trigger an immutable GC.
  //
  // It is assumed that this function is only called on allocation failures.
  bool ReleasePart(Heap* part);

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
  // TODO(kustermann): Instead of having a linked list which requires heap
  // allocations we should make a simple version of `std::vector` and use it
  // here.
  // [The number of parts is almost always fixed (i.e. the number of threads)]
  class HeapPart {
   public:
    HeapPart(HeapPart* next_part) : heap_part(NULL), next(next_part) {}

    Heap* heap_part;
    HeapPart* next;
  };

  bool HasUnmergedParts() { return unmerged_parts_ != NULL; }
  void AddUnmergedPart(Heap* heap);
  Heap* RemoveUnmergedPart();

  int number_of_hw_threads_;

  Mutex* heap_mutex_;
  Heap heap_;
  int outstanding_parts_;
  HeapPart* unmerged_parts_;
  int ticks_;
};

}  // namespace fletch


#endif  // SRC_VM_IMMUTABLE_HEAP_H_
