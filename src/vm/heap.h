// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HEAP_H_
#define SRC_VM_HEAP_H_

#include "src/shared/globals.h"
#include "src/shared/random.h"
#include "src/vm/object.h"
#include "src/vm/object_memory.h"
#include "src/vm/weak_pointer.h"

namespace fletch {

class ExitReference;

// Heap represents the container for all HeapObjects.
class Heap {
 public:
  explicit Heap(RandomLCG* random, int maximum_initial_size = 0);
  ~Heap();

  // Allocate raw object.
  Object* Allocate(int size);

  // Attempt to deallocate the heap object with the given size. Rewinds the
  // allocation top if the object was the last allocated object.
  void TryDealloc(Object* object, int size);

  // Allocate heap object.
  Object* CreateComplexHeapObject(Class* the_class, Object* init_value,
                                  bool immutable);

  // Allocate array.
  Object* CreateArray(Class* the_class, int length, Object* init_value,
                      bool immutable);

  // Allocate byte array.
  Object* CreateByteArray(Class* the_class, int length, bool immutable);

  // Allocate heap integer.
  Object* CreateLargeInteger(Class* the_class, int64 value);
  void TryDeallocInteger(LargeInteger* object);

  // Allocate double.
  Object* CreateDouble(Class* the_class, double value);

  // Allocate boxed.
  Object* CreateBoxed(Class* the_class, Object* value);

  // Allocate static variable info.
  Object* CreateInitializer(Class* the_class, Function* function);

  // Create a string object initialized with zeros. Caller should set
  // the actual contents.
  Object* CreateString(Class* the_class, int length, bool immutable);

  // Create a string object where the payload is uninitialized.
  // The payload therefore contains whatever was in the heap at this
  // location before. This should only be used if you are going
  // to immediately overwrite the payload with the actual data.
  Object* CreateStringUninitialized(Class* the_class, int length,
                                    bool immutable);

  // Allocate stack.
  Object* CreateStack(Class* the_class, int length, bool immutable);

  // Allocate class.
  Object* CreateMetaClass();
  Object* CreateClass(InstanceFormat format,
                      Class* meta_class,
                      HeapObject* null);

  // Allocate function.
  Object* CreateFunction(Class* the_class,
                         int arity,
                         List<uint8> bytecodes,
                         int number_of_literals);

  // Iterate over all objects in the heap.
  void IterateObjects(HeapObjectVisitor* visitor) {
    space_->IterateObjects(visitor);
  }

  // Flush will write cached values back to object memory.
  // Flush must be called before traveral of heap.
  void Flush() { space_->Flush(); }

  // Returns the number of bytes allocated in the space.
  int Used() { return space_->Used(); }

  Space* space() { return space_; }

  void ReplaceSpace(Space* space);
  Space* TakeSpace();
  WeakPointer* TakeWeakPointers();

  void MergeInOtherHeap(Heap* heap);

  // Adjust the allocation budget based on the current heap size.
  void AdjustAllocationBudget() { space()->AdjustAllocationBudget(); }

  // Tells whether garbage collection is needed.
  bool needs_garbage_collection() {
    return space()->needs_garbage_collection();
  }

  RandomLCG* random() { return random_; }

  void AddWeakPointer(HeapObject* object, WeakPointerCallback callback);
  void RemoveWeakPointer(HeapObject* object);
  void ProcessWeakPointers();
  void VisitWeakObjectPointers(PointerVisitor* visitor) {
    WeakPointer::Visit(weak_pointers_, visitor);
  }

 private:
  friend class ExitReference;
  friend class ImmutableHeap;
  Heap(Space* existing_space, WeakPointer* weak_pointers);

  Object* CreateStringInternal(Class* the_class, int length, bool clear,
                               bool immutable);

  Object* AllocateRawClass(int size);

  // Used for initializing identity hash codes for immutable objects.
  RandomLCG* random_;
  Space* space_;
  // Linked list of weak pointers to heap objects in this heap.
  WeakPointer* weak_pointers_;
};

// Helper class for copying HeapObjects.
class ScavengeVisitor: public PointerVisitor {
 public:
  ScavengeVisitor(Space* from, Space* to) : from_(from), to_(to) {}

  void Visit(Object** p) { ScavengePointer(p); }

  void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) ScavengePointer(p);
  }

 private:
  void ScavengePointer(Object** p) {
    Object* object = *p;
    if (!object->IsHeapObject()) return;
    if (!from_->Includes(reinterpret_cast<uword>(object))) return;
    *p = reinterpret_cast<HeapObject*>(object)->CloneInToSpace(to_);
  }

  Space* from_;
  Space* to_;
};

// Extract a raw void* pointer from [object].
//
// [object] must be either a Smi or a LargeInteger.
inline word AsForeignWord(Object* object) {
  return object->IsSmi()
      ? Smi::cast(object)->value()
      : LargeInteger::cast(object)->value();
}


}  // namespace fletch


#endif  // SRC_VM_HEAP_H_
