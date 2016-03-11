// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/weak_pointer.h"

#include <stdlib.h>

#include "src/vm/object.h"
#include "src/vm/object_memory.h"

namespace dartino {

WeakPointer::WeakPointer(HeapObject* object, WeakPointerCallback callback)
    : object_(object),
      callback_(reinterpret_cast<void*>(callback)),
      arg_(NULL) {}

WeakPointer::WeakPointer(HeapObject* object,
                         ExternalWeakPointerCallback callback, void* arg)
    : object_(object), callback_(reinterpret_cast<void*>(callback)), arg_(arg) {
  ASSERT(arg_ != NULL);
}

void WeakPointer::Invoke(Heap* heap) {
  if (arg_ == NULL) {
    reinterpret_cast<WeakPointerCallback>(callback_)(object_, heap);
  } else {
    reinterpret_cast<ExternalWeakPointerCallback>(callback_)(arg_);
  }
}

void WeakPointer::Process(Space* space, DoubleList<WeakPointer>* pointers,
                          Heap* heap) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    HeapObject* current_object = it->object_;
    if (space->Includes(current_object->address())) {
      if (space->IsAlive(current_object)) {
        it->object_ = space->NewLocation(current_object);
        ++it;
      } else {
        auto previous = *it;
        it = pointers->Erase(it);
        previous->Invoke(heap);
        delete previous;
      }
    } else {
      ++it;
    }
  }
}

void WeakPointer::ForceCallbacks(DoubleList<WeakPointer>* pointers,
                                 Heap* heap) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    it->Invoke(heap);
    auto previous = *it;
    it = pointers->Erase(it);
    delete previous;
  }
}

bool WeakPointer::Remove(DoubleList<WeakPointer>* pointers, HeapObject* object,
                         ExternalWeakPointerCallback callback) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    if (it->object_ == object && ((it->arg_ == NULL && callback == NULL) ||
                                  (it->callback_ == callback))) {
      auto previous = *it;
      it = pointers->Erase(it);
      delete previous;
      return true;
    } else {
      ++it;
    }
  }
  return false;
}

void WeakPointer::Visit(DoubleList<WeakPointer>* pointers,
                        PointerVisitor* visitor) {
  for (auto weak_pointer : *pointers) {
    visitor->Visit(reinterpret_cast<Object**>(&weak_pointer->object_));
  }
}

}  // namespace dartino
