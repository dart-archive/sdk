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
class OldSpace;
class PointerVisitor;
class WeakPointer;

typedef void (*WeakPointerCallback)(HeapObject* object, void* arg);
typedef void (*ExternalWeakPointerCallback)(void* arg);
typedef DoubleList<WeakPointer> WeakPointerList;

class WeakPointer : public WeakPointerList::Entry {
 public:
  WeakPointer(HeapObject* object, WeakPointerCallback callback, void* arg);

  WeakPointer(HeapObject* object, ExternalWeakPointerCallback callback,
              void* arg);

  static void Process(WeakPointerList* pointers, OldSpace* space);
  static void ProcessAndMoveSurvivors(WeakPointerList* pointers,
                                      Space* from_space, Space* to_space,
                                      Space* old_space);
  static void ForceCallbacks(WeakPointerList* pointers);
  static bool Remove(WeakPointerList* pointers, HeapObject* object,
                     ExternalWeakPointerCallback callback = nullptr);
  static void Visit(WeakPointerList* pointers, PointerVisitor* visitor);

 private:
  HeapObject* object_;
  void* callback_;
  void* arg_;
  bool external_;

  void Invoke();
};

}  // namespace dartino

#endif  // SRC_VM_WEAK_POINTER_H_
