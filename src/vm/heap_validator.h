// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HEAP_VALIDATOR_H_
#define SRC_VM_HEAP_VALIDATOR_H_

#include "src/vm/heap.h"
#include "src/vm/scheduler.h"

namespace fletch {

class SharedHeap;

// Validates that all pointers it gets called with lie inside certain spaces -
// depending on [process_heap], [program_heap].
class HeapPointerValidator : public PointerVisitor {
 public:
  HeapPointerValidator(Heap* program_heap, Heap* process_heap)
      : program_heap_(program_heap),
        process_heap_(process_heap) {}
  virtual ~HeapPointerValidator() {}

  virtual void VisitBlock(Object** start, Object** end);

 private:
  void ValidatePointer(Object* object);

  Heap* program_heap_;
  Heap* process_heap_;
};

// Validates that all pointers it gets called with lie inside the program heap.
class ProgramHeapPointerValidator : public HeapPointerValidator {
 public:
  explicit ProgramHeapPointerValidator(Heap* program_heap)
      : HeapPointerValidator(program_heap, NULL) {}
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
