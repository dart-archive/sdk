// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/shared_heap.h"
#include "src/vm/object_memory.h"
#include "src/vm/mark_sweep.h"

namespace fletch {

void SharedHeap::IterateProgramPointers(PointerVisitor* visitor) {
  HeapObjectPointerVisitor heap_pointer_visitor(visitor);
  heap_.IterateObjects(&heap_pointer_visitor);
}

}  // namespace fletch
