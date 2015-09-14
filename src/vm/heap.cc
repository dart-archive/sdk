// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/heap.h"

#include <stdio.h>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/vm/object.h"

namespace fletch {

Heap::Heap(RandomXorShift* random, int maximum_initial_size)
    : random_(random), space_(NULL), weak_pointers_(NULL) {
  space_ = new Space(maximum_initial_size);
  AdjustAllocationBudget();
}

Heap::Heap(Space* existing_space, WeakPointer* weak_pointers)
    : random_(NULL), space_(existing_space), weak_pointers_(weak_pointers) { }

Heap::~Heap() {
  WeakPointer::ForceCallbacks(&weak_pointers_);
  delete space_;
}

Object* Heap::Allocate(int size) {
  uword result = space_->Allocate(size);
  if (result == 0) return Failure::retry_after_gc();
  return HeapObject::FromAddress(result);
}

void Heap::TryDealloc(Object* object, int size) {
  uword location = reinterpret_cast<uword>(object) + size - HeapObject::kTag;
  space_->TryDealloc(location, size);
}

Object* Heap::CreateInstance(Class* the_class,
                             Object* init_value,
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

Object* Heap::CreateDouble(Class* the_class, double value) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::DOUBLE_TYPE);
  int size = Double::AllocationSize();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Double* result = reinterpret_cast<Double*>(raw_result);
  result->set_class(the_class);
  result->set_value(value);
  return Double::cast(result);
}

Object* Heap::CreateBoxed(Class* the_class, Object* value) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::BOXED_TYPE);
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

Object* Heap::CreateOneByteStringInternal(
    Class* the_class, int length, bool clear) {
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

Object* Heap::CreateTwoByteStringInternal(
    Class* the_class, int length, bool clear) {
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
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Stack* result = reinterpret_cast<Stack*>(raw_result);
  result->set_class(the_class);
  result->Initialize(length);
  return Stack::cast(result);
}

Object* Heap::AllocateRawClass(int size) {
  return Allocate(size);
}

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

Object* Heap::CreateClass(InstanceFormat format,
                          Class* meta_class,
                          HeapObject* null) {
  ASSERT(meta_class->instance_format().type() ==
         InstanceFormat::CLASS_TYPE);

  int size = meta_class->instance_format().fixed_size();
  Object* raw_result = Allocate(size);
  if (raw_result->IsFailure()) return raw_result;
  Class* result = reinterpret_cast<Class*>(raw_result);
  result->set_class(meta_class);
  result->Initialize(format, size, null);
  return Class::cast(result);  // Perform a cast to validate type.
}

Object* Heap::CreateFunction(Class* the_class,
                             int arity,
                             List<uint8> bytecodes,
                             int number_of_literals) {
  ASSERT(the_class->instance_format().type() ==
         InstanceFormat::FUNCTION_TYPE);
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

void Heap::ReplaceSpace(Space* space) {
  delete space_;
  space_ = space;
  AdjustAllocationBudget();
}

Space* Heap::TakeSpace() {
  Space* result = space_;
  space_ = NULL;
  return result;
}

WeakPointer* Heap::TakeWeakPointers() {
  WeakPointer* weak_pointers = weak_pointers_;
  weak_pointers_ = NULL;
  return weak_pointers;
}

void Heap::MergeInOtherHeap(Heap* heap) {
  Space* other_space = heap->TakeSpace();
  if (space_ == NULL) {
    space_ = other_space;
  } else {
    space_->PrependSpace(other_space);
  }

  WeakPointer* other_weak_pointers = heap->TakeWeakPointers();
  WeakPointer::PrependWeakPointers(&weak_pointers_, other_weak_pointers);
}

void Heap::AddWeakPointer(HeapObject* object,
                          WeakPointerCallback callback) {
  weak_pointers_ = new WeakPointer(object, callback, weak_pointers_);
}

void Heap::RemoveWeakPointer(HeapObject* object) {
  WeakPointer::Remove(&weak_pointers_, object);
}

void Heap::ProcessWeakPointers() {
  WeakPointer::Process(space(), &weak_pointers_);
}

}  // namespace fletch
