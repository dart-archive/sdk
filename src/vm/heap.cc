// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/heap.h"

#include <stdio.h>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/vm/object.h"

namespace dartino {

Heap::Heap(RandomXorShift* random, int maximum_initial_size)
    : random_(random),
      space_(new SemiSpace(maximum_initial_size)),
      old_space_(new OldSpace(0)),
      weak_pointers_(NULL),
      foreign_memory_(0),
      allocations_have_taken_place_(false) {
  AdjustAllocationBudget();
  AdjustOldAllocationBudget();
}

Heap::Heap(SemiSpace* existing_space, WeakPointer* weak_pointers)
    : random_(NULL),
      space_(existing_space),
      weak_pointers_(weak_pointers),
      foreign_memory_(0),
      allocations_have_taken_place_(false) {}

Heap::~Heap() {
  WeakPointer::ForceCallbacks(&weak_pointers_, this);
  ASSERT(foreign_memory_ == 0);
  delete old_space_;
  delete space_;
}

Object* Heap::Allocate(int size) {
  allocations_have_taken_place_ = true;
  uword result = space_->Allocate(size);
  if (result == 0) return Failure::retry_after_gc(size);
  return HeapObject::FromAddress(result);
}

Object* Heap::AllocateNonFatal(int size) {
  allocations_have_taken_place_ = true;
  uword result = space_->AllocateNonFatal(size);
  if (result == 0) return Failure::retry_after_gc(size);
  return HeapObject::FromAddress(result);
}

void Heap::TryDealloc(Object* object, int size) {
  uword location = reinterpret_cast<uword>(object) + size - HeapObject::kTag;
  space_->TryDealloc(location, size);
}

Object* Heap::CreateInstance(Class* the_class, Object* init_value,
                             bool immutable) {
  int size = the_class->instance_format().fixed_size();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Instance* result = reinterpret_cast<Instance*>(raw_result);
  result->set_class(the_class);
  result->set_immutable(immutable);
  if (immutable) result->InitializeIdentityHashCode(random());
  ASSERT(size == the_class->instance_format().fixed_size());
  result->Initialize(size, init_value);
  return result;
}

Object* Heap::CreateArray(Class* the_class, int length, Object* init_value) {
  ASSERT(the_class->instance_format().type() == InstanceFormat::ARRAY_TYPE);
  int size = Array::AllocationSize(length);
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Array* result = reinterpret_cast<Array*>(raw_result);
  result->set_class(the_class);
  result->Initialize(length, size, init_value);
  return Array::cast(result);
}

Object* Heap::CreateByteArray(Class* the_class, int length) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::BYTE_ARRAY_TYPE);
  int size = ByteArray::AllocationSize(length);
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  ByteArray* result = reinterpret_cast<ByteArray*>(raw_result);
  result->set_class(the_class);
  result->Initialize(length);
  return ByteArray::cast(result);
}

Object* Heap::CreateLargeInteger(Class* the_class, int64 value) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::LARGE_INTEGER_TYPE);
  int size = LargeInteger::AllocationSize();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  LargeInteger* result = reinterpret_cast<LargeInteger*>(raw_result);
  result->set_class(the_class);
  result->set_value(value);
  return LargeInteger::cast(result);
}

void Heap::TryDeallocInteger(LargeInteger* object) {
  TryDealloc(object, LargeInteger::AllocationSize());
}

Object* Heap::CreateDouble(Class* the_class, dartino_double value) {
  ASSERT(the_class->instance_format().type() == InstanceFormat::DOUBLE_TYPE);
  int size = Double::AllocationSize();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Double* result = reinterpret_cast<Double*>(raw_result);
  result->set_class(the_class);
  result->set_value(value);
  return Double::cast(result);
}

Object* Heap::CreateBoxed(Class* the_class, Object* value) {
  ASSERT(the_class->instance_format().type() == InstanceFormat::BOXED_TYPE);
  int size = the_class->instance_format().fixed_size();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Boxed* result = reinterpret_cast<Boxed*>(raw_result);
  result->set_class(the_class);
  result->set_value(value);
  return Boxed::cast(result);
}

Object* Heap::CreateInitializer(Class* the_class, Function* function) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::INITIALIZER_TYPE);
  int size = the_class->instance_format().fixed_size();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Initializer* result = reinterpret_cast<Initializer*>(raw_result);
  result->set_class(the_class);
  result->set_function(function);
  return Initializer::cast(result);
}

Object* Heap::CreateDispatchTableEntry(Class* the_class) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::DISPATCH_TABLE_ENTRY_TYPE);
  int size = DispatchTableEntry::AllocationSize();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  DispatchTableEntry* result =
      reinterpret_cast<DispatchTableEntry*>(raw_result);
  result->set_class(the_class);
  return DispatchTableEntry::cast(result);
}

Object* Heap::CreateOneByteStringInternal(Class* the_class, int length,
                                          bool clear) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::ONE_BYTE_STRING_TYPE);
  int size = OneByteString::AllocationSize(length);
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  OneByteString* result = reinterpret_cast<OneByteString*>(raw_result);
  result->set_class(the_class);
  result->Initialize(size, length, clear);
  return OneByteString::cast(result);
}

Object* Heap::CreateTwoByteStringInternal(Class* the_class, int length,
                                          bool clear) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::TWO_BYTE_STRING_TYPE);
  int size = TwoByteString::AllocationSize(length);
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  TwoByteString* result = reinterpret_cast<TwoByteString*>(raw_result);
  result->set_class(the_class);
  result->Initialize(size, length, clear);
  return TwoByteString::cast(result);
}

Object* Heap::CreateOneByteString(Class* the_class, int length) {
  return CreateOneByteStringInternal(the_class, length, true);
}

Object* Heap::CreateTwoByteString(Class* the_class, int length) {
  return CreateTwoByteStringInternal(the_class, length, true);
}

Object* Heap::CreateOneByteStringUninitialized(Class* the_class, int length) {
  return CreateOneByteStringInternal(the_class, length, false);
}

Object* Heap::CreateTwoByteStringUninitialized(Class* the_class, int length) {
  return CreateTwoByteStringInternal(the_class, length, false);
}

Object* Heap::CreateStack(Class* the_class, int length) {
  ASSERT(the_class->instance_format().type() == InstanceFormat::STACK_TYPE);
  int size = Stack::AllocationSize(length);
  Object* raw_result = AllocateNonFatal(size);
  if (raw_result->IsFailure()) return raw_result;
  Stack* result = reinterpret_cast<Stack*>(raw_result);
  result->set_class(the_class);
  result->Initialize(length);
  return Stack::cast(result);
}

Object* Heap::AllocateRawClass(int size) { return Allocate(size); }

Object* Heap::CreateMetaClass() {
  InstanceFormat format = InstanceFormat::class_format();
  int size = Class::AllocationSize();
  // Allocate the raw class objects.
  Class* meta_class = reinterpret_cast<Class*>(AllocateRawClass(size));
  if (meta_class->IsFailure()) return meta_class;
  // Bind the class loop.
  meta_class->set_class(meta_class);
  // Initialize the classes.
  meta_class->Initialize(format, size, NULL);
  return meta_class;
}

Object* Heap::CreateClass(InstanceFormat format, Class* meta_class,
                          HeapObject* null) {
  ASSERT(meta_class->instance_format().type() == InstanceFormat::CLASS_TYPE);

  int size = meta_class->instance_format().fixed_size();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Class* result = reinterpret_cast<Class*>(raw_result);
  result->set_class(meta_class);
  result->Initialize(format, size, null);
  return Class::cast(result);  // Perform a cast to validate type.
}

Object* Heap::CreateFunction(Class* the_class, int arity, List<uint8> bytecodes,
                             int number_of_literals) {
  ASSERT(the_class->instance_format().type() == InstanceFormat::FUNCTION_TYPE);
  int literals_size = number_of_literals * kPointerSize;
  int bytecode_size = Function::BytecodeAllocationSize(bytecodes.length());
  int size = Function::AllocationSize(bytecode_size + literals_size);
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Function* result = reinterpret_cast<Function*>(raw_result);
  result->set_class(the_class);
  result->set_arity(arity);
  result->set_literals_size(number_of_literals);
  result->Initialize(bytecodes);
  return Function::cast(result);
}

void Heap::AllocatedForeignMemory(int size) {
  ASSERT(foreign_memory_ >= 0);
  foreign_memory_ += size;
  old_space()->DecreaseAllocationBudget(size);
}

void Heap::FreedForeignMemory(int size) {
  foreign_memory_ -= size;
  ASSERT(foreign_memory_ >= 0);
  old_space()->IncreaseAllocationBudget(size);
}

void Heap::ReplaceSpace(SemiSpace* space, OldSpace* old_space) {
  delete space_;
  space_ = space;
  if (old_space != NULL) {
    // TODO(erikcorry): Fix this heuristic.
    // Currently the new-space GC time is dependent on the size of old space
    // because we have no remembered set.  Therefore we have to grow the new
    // space as the old space grows to avoid going quadratic.
    space->SetAllocationBudget(old_space->Used() >> 3);
  } else {
    AdjustAllocationBudget();
  }
}

SemiSpace* Heap::TakeSpace() {
  SemiSpace* result = space_;
  space_ = NULL;
  return result;
}

WeakPointer* Heap::TakeWeakPointers() {
  WeakPointer* weak_pointers = weak_pointers_;
  weak_pointers_ = NULL;
  return weak_pointers;
}

void Heap::AddWeakPointer(HeapObject* object, WeakPointerCallback callback) {
  weak_pointers_ = new WeakPointer(object, callback, weak_pointers_);
}

void Heap::RemoveWeakPointer(HeapObject* object) {
  WeakPointer::Remove(&weak_pointers_, object);
}

void Heap::ProcessWeakPointers(Space* space) {
  WeakPointer::Process(space, &weak_pointers_, this);
}

#ifdef DEBUG
void Heap::Find(uword word) {
  space_->Find(word, "Dartino heap");
  old_space_->Find(word, "oldspace");
#ifdef DARTINO_TARGET_OS_LINUX
  FILE* fp = fopen("/proc/self/maps", "r");
  if (fp == NULL) return;
  size_t length;
  char* line = NULL;
  while (getline(&line, &length, fp) > 0) {
    char* start;
    char* end;
    char r, w, x, p;  // Permissions.
    char filename[1000];
    memset(filename, 0, 1000);
    sscanf(line, "%p-%p %c%c%c%c %*x %*5c %*d %999c", &start, &end, &r, &w, &x,
           &p, &(filename[0]));
    // Don't search in mapped files.
    if (filename[0] != 0 && filename[0] != '[') continue;
    if (filename[0] == 0) {
      snprintf(filename, sizeof(filename), "anonymous: %p-%p %c%c%c%c", start,
               end, r, w, x, p);
    } else {
      if (filename[strlen(filename) - 1] == '\n') {
        filename[strlen(filename) - 1] = 0;
      }
    }
    // If we can't read it, skip.
    if (r != 'r') continue;
    for (char* current = start; current < end; current += 4) {
      uword w = *reinterpret_cast<uword*>(current);
      if (w == word) {
        fprintf(stderr, "Found %p in %s at %p\n", reinterpret_cast<void*>(w),
                filename, current);
      }
    }
  }
  fclose(fp);
#endif  // __linux
}
#endif  // DEBUG

}  // namespace dartino
