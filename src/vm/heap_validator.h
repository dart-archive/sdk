// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HEAP_VALIDATOR_H_
#define SRC_VM_HEAP_VALIDATOR_H_

#include "src/vm/heap.h"
#include "src/vm/scheduler.h"
#include "src/vm/stack_walker.h"

namespace fletch {

// Validates that all pointers it gets called with lie inside certain spaces -
// depending on [immutable_heap], [mutable_heap], [program_heap].
class HeapPointerValidator: public PointerVisitor {
 public:
  HeapPointerValidator(Heap* immutable_heap,
                       Heap* mutable_heap,
                       Heap* program_heap)
      : immutable_heap_(immutable_heap),
        mutable_heap_(mutable_heap),
        program_heap_(program_heap) {}
  virtual ~HeapPointerValidator() {}

  virtual void VisitBlock(Object** start, Object** end);

 private:
  void ValidatePointer(Object* object);

  Heap* immutable_heap_;
  Heap* mutable_heap_;
  Heap* program_heap_;
};

// Validates that all pointers it gets called with lie inside program/immutable
// heaps.
class ImmutableHeapPointerValidator: public HeapPointerValidator {
 public:
  ImmutableHeapPointerValidator(Heap* immutable_heap, Heap* program_heap)
      : HeapPointerValidator(immutable_heap, NULL, program_heap) {}
  virtual ~ImmutableHeapPointerValidator() {}
};

// Validates that all pointers it gets called with lie inside the program heap.
class ProgramHeapPointerValidator: public HeapPointerValidator {
 public:
  explicit ProgramHeapPointerValidator(Heap* program_heap)
      : HeapPointerValidator(NULL, NULL, program_heap) {}
  virtual ~ProgramHeapPointerValidator() {}
};

// Traverses roots, queues, heaps of a process and makes sure the pointers
// inside them are valid.
class ProcessHeapValidatorVisitor : public ProcessVisitor {
 public:
  explicit ProcessHeapValidatorVisitor(Heap* program_heap)
      : program_heap_(program_heap) {}
  virtual ~ProcessHeapValidatorVisitor() {}

  virtual void VisitProcess(Process* process);

 private:
  Heap* program_heap_;
};

}  // namespace fletch


#endif  // SRC_VM_HEAP_VALIDATOR_H_
