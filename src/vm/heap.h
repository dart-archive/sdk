// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HEAP_H_
#define SRC_VM_HEAP_H_

#include "src/shared/globals.h"
#include "src/shared/random.h"
#include "src/vm/object.h"
#include "src/vm/object_memory.h"
#include "src/vm/weak_pointer.h"

namespace dartino {

class ExitReference;

// Heap represents the container for all HeapObjects.
class Heap {
 public:
  // Allocate raw object. Returns a failure if a garbage collection is
  // needed and causes a fatal error if a GC cannot free up enough memory
  // for the object.
  Object* Allocate(int size);

  // Attempt to deallocate the heap object with the given size. Rewinds the
  // allocation top if the object was the last allocated object.
  void TryDealloc(Object* object, int size);

  // Called when an allocation fails in the semispace.  Usually returns a
  // retry-after-GC failure, but may divert large allocations to an old space.
  virtual Object* HandleAllocationFailure(int size) = 0;

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
  Object* CreateDouble(Class* the_class, dartino_double value);

  // Allocate boxed.
  Object* CreateBoxed(Class* the_class, Object* value);

  // Allocate static variable info.
  Object* CreateInitializer(Class* the_class, Function* function);

  // Allocate dispatch table entry.
  Object* CreateDispatchTableEntry(Class* the_class);

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
  Object* CreateClass(InstanceFormat format, Class* meta_class,
                      HeapObject* null);

  // Allocate function.
  Object* CreateFunction(Class* the_class, int arity, List<uint8> bytecodes,
                         int number_of_literals);

  void AllocatedForeignMemory(int size);

  void FreedForeignMemory(int size);

  // Iterate over all objects in the heap.
  virtual void IterateObjects(HeapObjectVisitor* visitor) {
    space_->IterateObjects(visitor);
  }

  // Flush will write cached values back to object memory.
  // Flush must be called before traveral of heap.
  virtual void Flush() { space_->Flush(); }

  // Returns the number of bytes allocated in the space.
  virtual int Used() { return space_->Used(); }

  // Returns the number of bytes allocated in the space and via foreign memory.
  int UsedTotal() { return Used() + foreign_memory_; }

  SemiSpace* space() { return space_; }

  void ReplaceSpace(SemiSpace* space);
  SemiSpace* TakeSpace();
  WeakPointer* TakeWeakPointers();

  bool allocations_have_taken_place() { return allocations_have_taken_place_; }

  RandomXorShift* random() { return random_; }

  int used_foreign_memory() { return foreign_memory_; }

  void AddWeakPointer(HeapObject* object, WeakPointerCallback callback);
  void RemoveWeakPointer(HeapObject* object);
  void ProcessWeakPointers(Space* space);
  void VisitWeakObjectPointers(PointerVisitor* visitor) {
    WeakPointer::Visit(weak_pointers_, visitor);
  }

#ifdef DEBUG
  // Used for debugging.  Give it an address, and it will tell you where there
  // are pointers to that address.  If the address is part of the heap it will
  // also tell you which part.  Reduced functionality if you are not on Linux,
  // since it uses the /proc filesystem.
  // To actually call this from gdb you probably need to remove the
  // --gc-sections flag from the linker in the build scripts.
  virtual void Find(uword word);
#endif

  // For asserts.
  virtual bool IsTwoSpaceHeap() { return false; }

 protected:
  friend class ExitReference;
  friend class Scheduler;
  friend class Program;

  Heap(SemiSpace* existing_space, WeakPointer* weak_pointers);
  explicit Heap(RandomXorShift* random);
  virtual ~Heap();

  Object* CreateOneByteStringInternal(Class* the_class, int length, bool clear);
  Object* CreateTwoByteStringInternal(Class* the_class, int length, bool clear);

  Object* AllocateRawClass(int size);

  // Adjust the allocation budget based on the current heap size.
  void AdjustAllocationBudget() { space()->AdjustAllocationBudget(0); }

  void set_random(RandomXorShift* random) { random_ = random; }

  // Used for initializing identity hash codes for immutable objects.
  RandomXorShift* random_;
  SemiSpace* space_;

  // The number of bytes of foreign memory heap objects are holding on to.
  int foreign_memory_;
  // Linked list of weak pointers to heap objects in this heap.
  WeakPointer* weak_pointers_;

 private:
  bool allocations_have_taken_place_;
};

class OneSpaceHeap : public Heap {
 public:
  explicit OneSpaceHeap(RandomXorShift* random, int maximum_initial_size = 0);

  virtual Object* HandleAllocationFailure(int size) {
    return Failure::retry_after_gc(size);
  }

#ifdef DEBUG
  virtual void Find(uword word);
#endif
};

class TwoSpaceHeap : public Heap {
 public:
  explicit TwoSpaceHeap(RandomXorShift* random);
  virtual ~TwoSpaceHeap();

  static const word kFixedSemiSpaceSize = 256 * KB;

  OldSpace* old_space() { return old_space_; }
  SemiSpace* unused_space() { return unused_semispace_; }

  void SwapSemiSpaces();

  // Iterate over all objects in the heap.
  virtual void IterateObjects(HeapObjectVisitor* visitor) {
    Heap::IterateObjects(visitor);
    old_space_->IterateObjects(visitor);
  }

  // Flush will write cached values back to object memory.
  // Flush must be called before traveral of heap.
  virtual void Flush() {
    Heap::Flush();
    old_space_->Flush();
  }

  // Returns the number of bytes allocated in the space.
  virtual int Used() { return old_space_->Used() + Heap::Used(); }

#ifdef DEBUG
  virtual void Find(uword word);
#endif

  void AdjustOldAllocationBudget() {
    old_space()->AdjustAllocationBudget(foreign_memory_);
  }

  virtual Object* HandleAllocationFailure(int size) {
    if (size >= (kFixedSemiSpaceSize >> 1)) {
      uword result = old_space_->Allocate(size);
      if (result != 0) return HeapObject::FromAddress(result);
    }
    return Failure::retry_after_gc(size);
  }

  // Used during object-rewriting to allocate directly in old-space when
  // new-space is full.
  Object* CreateOldSpaceInstance(Class* the_class, Object* init_value);

  virtual bool IsTwoSpaceHeap() { return true; }

 private:
  // Allocate or deallocate the pages used for heap metadata.
  void ManageMetadata(bool allocate);

  OldSpace* old_space_;
  SemiSpace* unused_semispace_;
};

// Helper class for copying HeapObjects.
class ScavengeVisitor : public PointerVisitor {
 public:
  ScavengeVisitor(SemiSpace* from, SemiSpace* to) : from_(from), to_(to) {}

  virtual void Visit(Object** p) { ScavengePointer(p); }

  virtual void VisitBlock(Object** start, Object** end) {
    // Copy all HeapObject pointers in [start, end)
    for (Object** p = start; p < end; p++) ScavengePointer(p);
  }

 private:
  void ScavengePointer(Object** p) {
    Object* object = *p;
    if (!object->IsHeapObject()) return;
    if (!from_->Includes(reinterpret_cast<uword>(object))) return;
    HeapObject* heap_object = reinterpret_cast<HeapObject*>(object);
    if (heap_object->HasForwardingAddress()) {
      *p = heap_object->forwarding_address();
    } else {
      *p = reinterpret_cast<HeapObject*>(object)->CloneInToSpace(to_);
    }
    ASSERT(*p != NULL);  // No-allocation scope should ensure this.
  }

  SemiSpace* from_;
  SemiSpace* to_;
};

// Helper class for copying HeapObjects.
class GenerationalScavengeVisitor : public PointerVisitor {
 public:
  GenerationalScavengeVisitor(SemiSpace* from, SemiSpace* to, OldSpace* old)
      : to_start_(to->start()),
        to_size_(to->size()),
        from_start_(from->start()),
        from_size_(from->size()),
        to_(to),
        old_(old),
        record_(&dummy_record_) {}

  virtual void VisitClass(Object** p) {}

  virtual void Visit(Object** p) { VisitBlock(p, p + 1); }

  inline bool InFromSpace(Object* object) {
    if (object->IsSmi()) return false;
    return reinterpret_cast<uword>(object) - from_start_ < from_size_;
  }

  inline bool InToSpace(Object* object) {
    if (object->IsSmi()) return false;
    return reinterpret_cast<uword>(object) - to_start_ < to_size_;
  }

  virtual void VisitBlock(Object** start, Object** end);

  bool trigger_old_space_gc() { return trigger_old_space_gc_; }

  void set_record_new_space_pointers(uint8* p) { record_ = p; }

 private:
  uword to_start_;
  uword to_size_;
  uword from_start_;
  uword from_size_;
  SemiSpace* to_;
  OldSpace* old_;
  int hacky_counter_ = 0;
  bool trigger_old_space_gc_ = false;
  uint8* record_;
  // Avoid checking for null by having a default place to write the remembered
  // set byte.
  uint8 dummy_record_;
};

// Read [object] as an integer word value.
//
// [object] must be either a Smi or a LargeInteger.
inline word AsForeignWord(Object* object) {
  return object->IsSmi() ? Smi::cast(object)->value()
                         : LargeInteger::cast(object)->value();
}

// Read [object] as an integer int64 value.
//
// [object] must be either a Smi or a LargeInteger.
inline int64 AsForeignInt64(Object* object) {
  return object->IsSmi() ? Smi::cast(object)->value()
                         : LargeInteger::cast(object)->value();
}

}  // namespace dartino

#endif  // SRC_VM_HEAP_H_
