// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_WEAK_POINTER_H_
#define SRC_VM_WEAK_POINTER_H_

#include "src/vm/double_list.h"

namespace dartino {

class HeapObject;
class Space;
class Heap;
class PointerVisitor;
class WeakPointer;

typedef void (*WeakPointerCallback)(HeapObject* object, Heap* heap);
typedef void (*ExternalWeakPointerCallback)(void* arg);
typedef DoubleList<WeakPointer> WeakPointerList;

class WeakPointer : public WeakPointerList::Entry {
 public:
  WeakPointer(HeapObject* object, WeakPointerCallback callback);

  WeakPointer(HeapObject* object, ExternalWeakPointerCallback callback,
              void* arg);

  static void Process(Space* garbage_space, DoubleList<WeakPointer>* pointers,
                      Heap* heap);
  static void ForceCallbacks(DoubleList<WeakPointer>* pointers, Heap* heap);
  static bool Remove(DoubleList<WeakPointer>* pointers, HeapObject* object,
                     ExternalWeakPointerCallback callback = nullptr);
  static void Visit(DoubleList<WeakPointer>* pointers, PointerVisitor* visitor);

 private:
  HeapObject* object_;
  void* callback_;
  void* arg_;

  void Invoke(Heap* heap);
};

}  // namespace dartino

#endif  // SRC_VM_WEAK_POINTER_H_
