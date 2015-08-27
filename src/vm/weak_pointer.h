// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_WEAK_POINTER_H_
#define SRC_VM_WEAK_POINTER_H_

namespace fletch {

class HeapObject;
class Space;
class PointerVisitor;

typedef void (*WeakPointerCallback)(HeapObject* object);

class WeakPointer {
 public:
  WeakPointer(HeapObject* object,
              WeakPointerCallback callback,
              WeakPointer* next);

  static void Process(Space* garbage_space, WeakPointer** pointers);
  static void ForceCallbacks(WeakPointer** pointers);
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

}  // namespace fletch

#endif  // SRC_VM_WEAK_POINTER_H_
