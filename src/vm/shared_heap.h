// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SHARED_HEAP_H_
#define SRC_VM_SHARED_HEAP_H_

#include "src/shared/globals.h"
#include "src/vm/heap.h"

namespace fletch {

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

}  // namespace fletch

#endif  // SRC_VM_SHARED_HEAP_H_
