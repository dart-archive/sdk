// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/heap_validator.h"
#include "src/vm/process.h"

namespace fletch {

void HeapPointerValidator::VisitBlock(Object** start, Object** end) {
  for (; start != end; start++) {
    ValidatePointer(*start);
  }
}

void HeapPointerValidator::ValidatePointer(Object* object) {
  if (!object->IsHeapObject()) return;

  HeapObject* heap_object = HeapObject::cast(object);
  uword address = heap_object->address();

  bool is_shared_heap_obj = false;
  if (shared_heap_ != NULL) {
    is_shared_heap_obj = shared_heap_->heap()->space()->Includes(address);
  }
  bool is_mutable_heap_obj = false;
  if (mutable_heap_ != NULL) {
    is_mutable_heap_obj = mutable_heap_->space()->Includes(address);
  }

  bool is_program_heap = program_heap_->space()->Includes(address);

  if (!is_shared_heap_obj && !is_mutable_heap_obj && !is_program_heap &&
      !StaticClassStructures::IsStaticClass(heap_object)) {
    fprintf(stderr,
            "Found pointer %p which lies in neither of "
            "immutable_heap/mutable_heap/program_heap.\n",
            heap_object);

    FATAL("Heap validation failed.");
  }

  Class* klass = heap_object->get_class();
  bool valid_class = program_heap_->space()->Includes(klass->address()) ||
                     StaticClassStructures::IsStaticClass(klass);
  if (!valid_class) {
    fprintf(stderr, "Object %p had an invalid klass pointer %p\n", heap_object,
            klass);
    FATAL("Heap validation failed.");
  }
}

void ProcessHeapValidatorVisitor::VisitProcess(Process* process) {
  Heap* process_heap = process->heap();

  // Validate pointers in roots, queues, weak pointers and mutable heap.
  {
    HeapPointerValidator validator(program_heap_, shared_heap_, process_heap);

    HeapObjectPointerVisitor pointer_visitor(&validator);
    process->IterateRoots(&validator);
    process_heap->IterateObjects(&pointer_visitor);
    process_heap->VisitWeakObjectPointers(&validator);
    process->store_buffer()->IterateObjects(&pointer_visitor);
    process->mailbox()->IteratePointers(&validator);
  }
}

}  // namespace fletch
