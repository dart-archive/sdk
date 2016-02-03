// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/object_list.h"

namespace dartino {

ObjectList::ObjectList(int capacity) {
  contents_ = List<Object*>::New(capacity);
  length_ = 0;
}

ObjectList::~ObjectList() { contents_.Delete(); }

void ObjectList::Add(Object* object) {
  int index = length_++;
  if (index == contents_.length()) {
    contents_.Reallocate(index + (1 * KB));
  }
  contents_[index] = object;
}

void ObjectList::Clear() { length_ = 0; }

void ObjectList::IteratePointers(PointerVisitor* visitor) {
  Object** stack_start = contents_.data();
  Object** stack_end = stack_start + length_;
  visitor->VisitBlock(stack_start, stack_end);
}

}  // namespace dartino
