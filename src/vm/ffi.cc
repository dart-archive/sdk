// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/ffi.h"

#include "src/shared/asan_helper.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"

namespace dartino {

BEGIN_NATIVE(ForeignAllocate) {
  if (!arguments[0]->IsSmi() && !arguments[0]->IsLargeInteger()) {
    return Failure::wrong_argument_type();
  }
  word size = AsForeignWord(arguments[0]);
  Object* result = process->NewInteger(0);
  if (result->IsRetryAfterGCFailure()) return result;
  void* calloc_value = calloc(1, size);
  uint64 value = reinterpret_cast<uint64>(calloc_value);

// If we might be using a leak sanitizer, we'll always use a LargeInteger to
// hold the memory pointer in order for the leak sanitizer to find pointers to
// malloc()ed memory regions which are referenced by dart [Foreign] objects.
#ifndef PROBABLY_USING_LEAK_SANITIZER
  if (Smi::IsValid(value)) {
    process->TryDeallocInteger(LargeInteger::cast(result));
    return Smi::FromWord(value);
  }
#endif
  LargeInteger::cast(result)->set_value(value);
  return result;
}
END_NATIVE()

BEGIN_NATIVE(ForeignFree) {
  uword address = Instance::cast(arguments[0])->GetConsecutiveSmis(0);
  free(reinterpret_cast<void*>(address));
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(ForeignDecreaseMemoryUsage) {
  HeapObject* foreign = HeapObject::cast(arguments[0]);
  int size = static_cast<int>(AsForeignWord(arguments[1]));
  // For immutable objects that have been marked as finalized, we should never
  // manually free it, hence the following assert.
  ASSERT(!foreign->IsImmutable());
  process->heap()->FreedForeignMemory(size);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(ForeignMarkForFinalization) {
  HeapObject* foreign = HeapObject::cast(arguments[0]);
  int size = static_cast<int>(AsForeignWord(arguments[1]));
  process->heap()->AllocatedForeignMemory(size);
  process->RegisterFinalizer(foreign, Process::FinalizeForeign);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(ForeignRegisterFinalizer) {
  auto callback = reinterpret_cast<ExternalWeakPointerCallback>(
      AsForeignWord(arguments[1]));
  if (!arguments[0]->IsHeapObject()) return Failure::wrong_argument_type();
  HeapObject* object = HeapObject::cast(arguments[0]);
  void* argument = reinterpret_cast<void*>(AsForeignWord(arguments[2]));
  if (argument == NULL) return Failure::illegal_state();
  process->RegisterExternalFinalizer(object, callback, argument);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(ForeignRemoveFinalizer) {
  auto callback = reinterpret_cast<ExternalWeakPointerCallback>(
      AsForeignWord(arguments[1]));
  if (!arguments[0]->IsHeapObject()) return Failure::wrong_argument_type();
  HeapObject* object = HeapObject::cast(arguments[0]);
  bool result = process->UnregisterExternalFinalizer(object, callback);
  return result ? process->program()->true_object()
                : process->program()->false_object();
}
END_NATIVE()

BEGIN_NATIVE(ForeignBitsPerWord) { return Smi::FromWord(kBitsPerWord); }
END_NATIVE()

BEGIN_NATIVE(ForeignPlatform) { return Smi::FromWord(Platform::OS()); }
END_NATIVE()

BEGIN_NATIVE(ForeignArchitecture) { return Smi::FromWord(Platform::Arch()); }
END_NATIVE()

BEGIN_NATIVE(ForeignConvertPort) {
  if (!arguments[0]->IsInstance()) return Smi::zero();
  Instance* instance = Instance::cast(arguments[0]);
  if (!instance->IsPort()) return Smi::zero();
  Port* port = Port::FromDartObject(instance);
  if (port == NULL) return Smi::zero();
  Object* result = process->ToInteger(reinterpret_cast<intptr_t>(port));
  if (result->IsRetryAfterGCFailure()) return result;
  port->IncrementRef();
  return result;
}
END_NATIVE()

typedef int (*F0)();
typedef int (*F1)(word);
typedef int (*F2)(word, word);
typedef int (*F3)(word, word, word);
typedef int (*F4)(word, word, word, word);
typedef int (*F5)(word, word, word, word, word);
typedef int (*F6)(word, word, word, word, word, word);
typedef int (*F7)(word, word, word, word, word, word, word);

BEGIN_DETACHABLE_NATIVE(ForeignICall0) {
  word address = AsForeignWord(arguments[0]);
  F0 function = reinterpret_cast<F0>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function()));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  F1 function = reinterpret_cast<F1>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  F2 function = reinterpret_cast<F2>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  F3 function = reinterpret_cast<F3>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1, a2)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  F4 function = reinterpret_cast<F4>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1, a2, a3)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  F5 function = reinterpret_cast<F5>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(
      static_cast<int64>(function(a0, a1, a2, a3, a4)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  F6 function = reinterpret_cast<F6>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(
      static_cast<int64>(function(a0, a1, a2, a3, a4, a5)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignICall7) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  word a6 = AsForeignWord(arguments[7]);
  F7 function = reinterpret_cast<F7>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(
      static_cast<int64>(function(a0, a1, a2, a3, a4, a5, a6)));
}
END_NATIVE()

typedef word (*PF0)();
typedef word (*PF1)(word);
typedef word (*PF2)(word, word);
typedef word (*PF3)(word, word, word);
typedef word (*PF4)(word, word, word, word);
typedef word (*PF5)(word, word, word, word, word);
typedef word (*PF6)(word, word, word, word, word, word);

BEGIN_DETACHABLE_NATIVE(ForeignPCall0) {
  word address = AsForeignWord(arguments[0]);
  PF0 function = reinterpret_cast<PF0>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function()));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  PF1 function = reinterpret_cast<PF1>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  PF2 function = reinterpret_cast<PF2>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  PF3 function = reinterpret_cast<PF3>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1, a2)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  PF4 function = reinterpret_cast<PF4>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(static_cast<int64>(function(a0, a1, a2, a3)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  PF5 function = reinterpret_cast<PF5>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(
      static_cast<int64>(function(a0, a1, a2, a3, a4)));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignPCall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  PF6 function = reinterpret_cast<PF6>(address);
  RUN_INSIDE_BARRIER_AND_RETURN(
      static_cast<int64>(function(a0, a1, a2, a3, a4, a5)));
}
END_NATIVE()

typedef void (*VF0)();
typedef void (*VF1)(word);
typedef void (*VF2)(word, word);
typedef void (*VF3)(word, word, word);
typedef void (*VF4)(word, word, word, word);
typedef void (*VF5)(word, word, word, word, word);
typedef void (*VF6)(word, word, word, word, word, word);

BEGIN_DETACHABLE_NATIVE(ForeignVCall0) {
  word address = AsForeignWord(arguments[0]);
  VF0 function = reinterpret_cast<VF0>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function());
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  VF1 function = reinterpret_cast<VF1>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  VF2 function = reinterpret_cast<VF2>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0, a1));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  VF3 function = reinterpret_cast<VF3>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0, a1, a2));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  VF4 function = reinterpret_cast<VF4>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0, a1, a2, a3));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  VF5 function = reinterpret_cast<VF5>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0, a1, a2, a3, a4));
}
END_NATIVE()

BEGIN_DETACHABLE_NATIVE(ForeignVCall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  VF6 function = reinterpret_cast<VF6>(address);
  RUN_INSIDE_BARRIER_AND_RETURN_VOID(function(a0, a1, a2, a3, a4, a5));
}
END_NATIVE()

typedef int64 (*LwLw)(word, int64, word);

static int64 AsInt64Value(Object* object) {
  if (object->IsSmi()) return Smi::cast(object)->value();
  if (object->IsLargeInteger()) return LargeInteger::cast(object)->value();
  UNREACHABLE();
  return -1;
}

BEGIN_NATIVE(ForeignLCallwLw) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  int64 a1 = AsInt64Value(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  LwLw function = reinterpret_cast<LwLw>(address);
  Object* result = process->NewInteger(0);
  if (result->IsRetryAfterGCFailure()) return result;
  int64 value = function(a0, a1, a2);
  if (Smi::IsValid(value)) {
    process->TryDeallocInteger(LargeInteger::cast(result));
    return Smi::FromWord(value);
  }
  LargeInteger::cast(result)->set_value(value);
  return result;
}
END_NATIVE()

#define DEFINE_FOREIGN_ACCESSORS_INTEGER(suffix, type)                    \
                                                                          \
  BEGIN_NATIVE(ForeignGet##suffix) {                                      \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    return process->ToInteger(*address);                                  \
  }                                                                       \
  END_NATIVE()                                                            \
                                                                          \
  BEGIN_NATIVE(ForeignSet##suffix) {                                      \
    Object* value = arguments[1];                                         \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    if (value->IsSmi()) {                                                 \
      *address = Smi::cast(value)->value();                               \
    } else if (value->IsLargeInteger()) {                                 \
      *address = LargeInteger::cast(value)->value();                      \
    } else {                                                              \
      return Failure::wrong_argument_type();                              \
    }                                                                     \
    return value;                                                         \
  }                                                                       \
  END_NATIVE()

DEFINE_FOREIGN_ACCESSORS_INTEGER(Int8, int8)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Int16, int16)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Int32, int32)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Int64, int64)

DEFINE_FOREIGN_ACCESSORS_INTEGER(Uint8, uint8)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Uint16, uint16)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Uint32, uint32)
DEFINE_FOREIGN_ACCESSORS_INTEGER(Uint64, uint64)

#define DEFINE_FOREIGN_ACCESSORS_DOUBLE(suffix, type)                     \
                                                                          \
  BEGIN_NATIVE(ForeignGet##suffix) {                                      \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    return process->NewDouble(static_cast<double>(*address));             \
  }                                                                       \
  END_NATIVE()                                                            \
                                                                          \
  BEGIN_NATIVE(ForeignSet##suffix) {                                      \
    Object* value = arguments[1];                                         \
    if (!value->IsDouble()) return Failure::wrong_argument_type();        \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    *address = Double::cast(value)->value();                              \
    return value;                                                         \
  }                                                                       \
  END_NATIVE()

DEFINE_FOREIGN_ACCESSORS_DOUBLE(Float32, float)
DEFINE_FOREIGN_ACCESSORS_DOUBLE(Float64, double)

#undef DEFINE_FOREIGN_ACCESSORS

}  // namespace dartino
