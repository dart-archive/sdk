// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_WEAK_POINTER_H_
#define SRC_VM_WEAK_POINTER_H_

namespace dartino {

class HeapObject;
class Space;
class Heap;
class PointerVisitor;

typedef void (*WeakPointerCallback)(HeapObject* object, Heap* heap);

class WeakPointer {
 public:
  WeakPointer(HeapObject* object, WeakPointerCallback callback,
              WeakPointer* next);

  static void Process(Space* garbage_space, WeakPointer** pointers, Heap* heap);
  static void ForceCallbacks(WeakPointer** pointers, Heap* heap);
  static void Remove(WeakPointer** pointers, HeapObject* object);
  static void PrependWeakPointers(WeakPointer** pointers,
                                  WeakPointer* to_be_prepended);
  static void Visit(WeakPointer* pointers, PointerVisitor* visitor);

 private:
  HeapObject* object_;
  WeakPointerCallback callback_;
  WeakPointer* prev_;
  WeakPointer* next_;
};

}  // namespace dartino

#endif  // SRC_VM_WEAK_POINTER_H_
