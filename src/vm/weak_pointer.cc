// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/weak_pointer.h"

#include <stdlib.h>

#include "src/vm/object.h"
#include "src/vm/object_memory.h"

namespace dartino {

WeakPointer::WeakPointer(HeapObject* object, WeakPointerCallback callback,
                         void* arg)
    : object_(object),
      callback_(reinterpret_cast<void*>(callback)),
      arg_(arg),
      external_(false) {}

WeakPointer::WeakPointer(HeapObject* object,
                         ExternalWeakPointerCallback callback, void* arg)
    : object_(object),
      callback_(reinterpret_cast<void*>(callback)),
      arg_(arg),
      external_(true) {}

void WeakPointer::Invoke() {
  if (external_) {
    reinterpret_cast<ExternalWeakPointerCallback>(callback_)(arg_);
  } else {
    reinterpret_cast<WeakPointerCallback>(callback_)(object_, arg_);
  }
}

void WeakPointer::ProcessAndMoveSurvivors(WeakPointerList* pointers,
                                          Space* from_space, Space* to_space,
                                          Space* old_space) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    HeapObject* current_object = it->object_;
    auto previous = *it;
    it = pointers->Erase(it);
    ASSERT(from_space->Includes(current_object->address()));
    if (from_space->IsAlive(current_object)) {
      HeapObject* new_object = previous->object_ =
          from_space->NewLocation(current_object);
      if (to_space->IsInSingleChunk(new_object)) {
        to_space->weak_pointers()->Append(previous);
      } else {
        ASSERT(old_space->Includes(new_object->address()));
        old_space->weak_pointers()->Append(previous);
      }
    } else {
      // Object died.  Invoke
      previous->Invoke();
      delete previous;
    }
  }
}

void WeakPointer::Process(WeakPointerList* pointers, Space* space) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    HeapObject* current_object = it->object_;
    ASSERT(space->Includes(current_object->address()));
    if (!space->IsAlive(current_object)) {
      auto previous = *it;
      it = pointers->Erase(it);
      // Object died.  Invoke
      previous->Invoke();
      delete previous;
    } else {
      // We don't move old-space objects.
      ++it;
    }
  }
}

void WeakPointer::ForceCallbacks(WeakPointerList* pointers) {
  for (auto it = pointers->Begin(); it != pointers->End();) {
    it->Invoke();
    auto previous = *it;
    it = pointers->Erase(it);
    delete previous;
  }
}

bool WeakPointer::Remove(WeakPointerList* pointers, HeapObject* object,
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

void WeakPointer::Visit(WeakPointerList* pointers,
                        PointerVisitor* visitor) {
  for (auto weak_pointer : *pointers) {
    visitor->Visit(reinterpret_cast<Object**>(&weak_pointer->object_));
  }
}

}  // namespace dartino
