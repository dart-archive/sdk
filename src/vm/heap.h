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
  explicit Heap(RandomXorShift* random, int maximum_initial_size = 0);
  ~Heap();

  // Allocate raw object. Returns a failure if a garbage collection is
  // needed and causes a fatal error if no garbage collection is
  // needed and there is not enough room for the object.
  Object* Allocate(int size);

  // Allocate raw object. Returns a failure if a garbage collection is
  // needed or if there is not enough room for the object. Never causes
  // a fatal error.
  Object* AllocateNonFatal(int size);

  // Attempt to deallocate the heap object with the given size. Rewinds the
  // allocation top if the object was the last allocated object.
  void TryDealloc(Object* object, int size);

  // Allocate heap object.
  Object* CreateInstance(Class* the_class, Object* init_value, bool immutable);

  // Allocate array.
  Object* CreateArray(Class* the_class, int length, Object* init_value);

  // Allocate byte array.
  Object* CreateByteArray(Class* the_class, int length);

  // Allocate heap integer.
  Object* CreateLargeInteger(Class* the_class, int64 value);
  void TryDeallocInteger(LargeInteger* object);

  // Allocate double.
  Object* CreateDouble(Class* the_class, fletch_double value);

  // Allocate boxed.
  Object* CreateBoxed(Class* the_class, Object* value);

  // Allocate static variable info.
  Object* CreateInitializer(Class* the_class, Function* function);

  // Create a string object initialized with zeros. Caller should set
  // the actual contents.
  Object* CreateOneByteString(Class* the_class, int length);
  Object* CreateTwoByteString(Class* the_class, int length);

  // Create a string object where the payload is uninitialized.
  // The payload therefore contains whatever was in the heap at this
  // location before. This should only be used if you are going
  // to immediately overwrite the payload with the actual data.
  Object* CreateOneByteStringUninitialized(Class* the_class, int length);
  Object* CreateTwoByteStringUninitialized(Class* the_class, int length);

  // Allocate stack. Never causes a fatal error in out of memory
  // situations. The caller must deal with repeated failure results.
  Object* CreateStack(Class* the_class, int length);

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

  void AllocatedForeignMemory(int size);

  void FreedForeignMemory(int size);

  // Iterate over all objects in the heap.
  void IterateObjects(HeapObjectVisitor* visitor) {
    space_->IterateObjects(visitor);
  }

  // Flush will write cached values back to object memory.
  // Flush must be called before traveral of heap.
  void Flush() { space_->Flush(); }

  // Returns the number of bytes allocated in the space.
  int Used() { return space_->Used(); }

  // Returns the number of bytes allocated in the space and via foreign memory.
  int UsedTotal() { return space_->Used() + foreign_memory_; }

  Space* space() { return space_; }

  void ReplaceSpace(Space* space);
  Space* TakeSpace();
  WeakPointer* TakeWeakPointers();

  void MergeInOtherHeap(Heap* heap);

  // Tells whether garbage collection is needed.
  bool needs_garbage_collection() {
    return space()->needs_garbage_collection();
  }

  RandomXorShift* random() { return random_; }

  int used_foreign_memory() { return foreign_memory_; }

  void AddWeakPointer(HeapObject* object, WeakPointerCallback callback);
  void RemoveWeakPointer(HeapObject* object);
  void ProcessWeakPointers();
  void VisitWeakObjectPointers(PointerVisitor* visitor) {
    WeakPointer::Visit(weak_pointers_, visitor);
  }

 private:
  friend class ExitReference;
  friend class SharedHeap;
  friend class Scheduler;
  friend class Program;

  Heap(Space* existing_space, WeakPointer* weak_pointers);

  Object* CreateOneByteStringInternal(Class* the_class, int length, bool clear);
  Object* CreateTwoByteStringInternal(Class* the_class, int length, bool clear);

  Object* AllocateRawClass(int size);

  // Adjust the allocation budget based on the current heap size.
  void AdjustAllocationBudget() {
    space()->AdjustAllocationBudget(foreign_memory_);
  }

  void set_random(RandomXorShift* random) {
    random_ = random;
  }

  // Used for initializing identity hash codes for immutable objects.
  RandomXorShift* random_;
  Space* space_;
  // Linked list of weak pointers to heap objects in this heap.
  WeakPointer* weak_pointers_;
  // The number of bytes of foreign memory heap objects are holding on to.
  int foreign_memory_;
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

// Read [object] as an integer word value.
//
// [object] must be either a Smi or a LargeInteger.
inline word AsForeignWord(Object* object) {
  return object->IsSmi()
      ? Smi::cast(object)->value()
      : LargeInteger::cast(object)->value();
}

// Read [object] as an integer int64 value.
//
// [object] must be either a Smi or a LargeInteger.
inline int64 AsForeignInt64(Object* object) {
  return object->IsSmi()
      ? Smi::cast(object)->value()
      : LargeInteger::cast(object)->value();
}


}  // namespace fletch


#endif  // SRC_VM_HEAP_H_
