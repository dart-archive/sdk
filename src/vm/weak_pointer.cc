// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/weak_pointer.h"

#include <stdlib.h>

#include "src/vm/object.h"

namespace fletch {

WeakPointer::WeakPointer(HeapObject* object,
                         WeakPointerCallback callback,
                         WeakPointer* next)
    : object_(object),
      callback_(callback),
      prev_(NULL),
      next_(next) { }

void WeakPointer::Process(WeakPointer** pointers) {
  WeakPointer* new_list = NULL;
  WeakPointer* previous = NULL;
  WeakPointer* current = *pointers;
  while (current != NULL) {
    WeakPointer* next = current->next_;
    HeapObject* forward = current->object_->forwarding_address();
    if (forward != NULL) {
      current->object_ = forward;
      if (new_list == NULL) new_list = current;
      previous = current;
    } else {
      if (current->next_ != NULL) current->next_->prev_ = previous;
      if (previous != NULL) previous->next_ = current->next_;
      current->callback_(current->object_);
      delete current;
    }
    current = next;
  }
  *pointers = new_list;
}

void WeakPointer::ForceCallbacks(WeakPointer** pointers) {
  WeakPointer* current = *pointers;
  while (current != NULL) {
    WeakPointer* temp = current->next_;
    current->callback_(current->object_);
    delete current;
    current = temp;
  }
  *pointers = NULL;
}

void WeakPointer::Remove(WeakPointer** pointers, HeapObject* object) {
  WeakPointer* current = *pointers;
  WeakPointer* previous = NULL;
  while (current != NULL) {
    if (current->object_ == object) {
      if (previous == NULL) {
        *pointers = current->next_;
      } else {
        previous->next_ = current->next_;
      }
      if (current->next_ != NULL) current->next_->prev_ = previous;
      delete current;
      return;
    } else {
      previous = current;
      current = current->next_;
    }
  }
}

}  // namespace fletch
