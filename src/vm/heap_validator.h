// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HEAP_VALIDATOR_H_
#define SRC_VM_HEAP_VALIDATOR_H_

#include "src/vm/heap.h"
#include "src/vm/scheduler.h"

namespace fletch {

class SharedHeap;

// Validates that all pointers it gets called with lie inside certain spaces -
// depending on [shared_heap], [mutable_heap], [program_heap].
class HeapPointerValidator : public PointerVisitor {
 public:
  HeapPointerValidator(Heap* program_heap, SharedHeap* shared_heap,
                       Heap* mutable_heap)
      : program_heap_(program_heap),
        shared_heap_(shared_heap),
        mutable_heap_(mutable_heap) {}
  virtual ~HeapPointerValidator() {}

  virtual void VisitBlock(Object** start, Object** end);

 private:
  void ValidatePointer(Object* object);

  Heap* program_heap_;
  SharedHeap* shared_heap_;
  Heap* mutable_heap_;
};

// Validates that all pointers it gets called with lie inside program/immutable
// heaps.
class SharedHeapPointerValidator : public HeapPointerValidator {
 public:
  SharedHeapPointerValidator(Heap* program_heap, SharedHeap* shared_heap)
      : HeapPointerValidator(program_heap, shared_heap, NULL) {}
  virtual ~SharedHeapPointerValidator() {}
};

// Validates that all pointers it gets called with lie inside the program heap.
class ProgramHeapPointerValidator : public HeapPointerValidator {
 public:
  explicit ProgramHeapPointerValidator(Heap* program_heap)
      : HeapPointerValidator(program_heap, NULL, NULL) {}
  virtual ~ProgramHeapPointerValidator() {}
};

// Traverses roots, queues, heaps of a process and makes sure the pointers
// inside them are valid.
class ProcessHeapValidatorVisitor : public ProcessVisitor {
 public:
  explicit ProcessHeapValidatorVisitor(Heap* program_heap,
                                       SharedHeap* shared_heap)
      : program_heap_(program_heap), shared_heap_(shared_heap) {}
  virtual ~ProcessHeapValidatorVisitor() {}

  virtual void VisitProcess(Process* process);

 private:
  Heap* program_heap_;
  SharedHeap* shared_heap_;
};

}  // namespace fletch

#endif  // SRC_VM_HEAP_VALIDATOR_H_
