// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/ffi.h"

#include "src/shared/asan_helper.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/vector.h"

namespace dartino {

BEGIN_LEAF_NATIVE(ForeignAllocate) {
  if (!arguments[0]->IsSmi() && !arguments[0]->IsLargeInteger()) {
    return Failure::wrong_argument_type();
  }
  Object* cached_integer = process->EnsureLargeIntegerIsAvailable();
  if (cached_integer->IsRetryAfterGCFailure()) return cached_integer;

  word size = AsForeignWord(arguments[0]);
  void* calloc_value = calloc(1, size);
  uint64 value = reinterpret_cast<uint64>(calloc_value);

// If we might be using a leak sanitizer, always use a LargeInteger to
// hold the memory pointer in order for the leak sanitizer to find pointers to
// malloc()ed memory regions which are referenced by dart [Foreign] objects.
#ifndef PROBABLY_USING_LEAK_SANITIZER
  if (Smi::IsValid(value)) return Smi::FromWord(value);
#endif
  LargeInteger* result = process->ConsumeLargeInteger();
  result->set_value(value);
  return result;
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignFree) {
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
  process->RegisterFinalizer(foreign, Process::FinalizeForeign,
                             process->heap());
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignRegisterFinalizer) {
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

BEGIN_LEAF_NATIVE(ForeignRemoveFinalizer) {
  auto callback = reinterpret_cast<ExternalWeakPointerCallback>(
      AsForeignWord(arguments[1]));
  if (!arguments[0]->IsHeapObject()) return Failure::wrong_argument_type();
  HeapObject* object = HeapObject::cast(arguments[0]);
  bool result = process->UnregisterExternalFinalizer(object, callback);
  return result ? process->program()->true_object()
                : process->program()->false_object();
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignBitsPerWord) { return Smi::FromWord(kBitsPerWord); }
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignBitsPerDouble) {
  return Smi::FromWord(kBitsPerDartinoDouble);
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignPlatform) { return Smi::FromWord(Platform::OS()); }
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignArchitecture) {
  return Smi::FromWord(Platform::Arch());
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignConvertPort) {
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

BEGIN_LEAF_NATIVE(ForeignDoubleToSignedBits) {
  if (!arguments[0]->IsDouble()) return Failure::wrong_argument_type();

  dartino_double value = Double::cast(arguments[0])->value();
  dartino_double_as_int result = bit_cast<dartino_double_as_int>(value);
  if (Smi::IsValid(result)) return Smi::FromWord(result);
  // The allocation of the integer might fail in which case the interpreter
  // will do a GC and run this function again.
  return process->NewInteger(result);
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignSignedBitsToDouble) {
  Object* object = arguments[0];
  dartino_double_as_int bits;
  if (object->IsSmi()) {
    bits = static_cast<dartino_double_as_int>(Smi::cast(object)->value());
  } else if (object->IsLargeInteger()) {
    bits =
        static_cast<dartino_double_as_int>(LargeInteger::cast(object)->value());
  } else {
    return Failure::wrong_argument_type();
  }
  // The allocation of the double might fail in which case the interpreter
  // will do a GC and run this function again.
  return process->NewDouble(bit_cast<dartino_double>(bits));
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

BEGIN_NATIVE(ForeignICall0) {
  word address = AsForeignWord(arguments[0]);
  F0 function = reinterpret_cast<F0>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function()));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  F1 function = reinterpret_cast<F1>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  F2 function = reinterpret_cast<F2>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0, a1)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  F3 function = reinterpret_cast<F3>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0, a1, a2)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  F4 function = reinterpret_cast<F4>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
    static_cast<int64>(function(a0, a1, a2, a3)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  F5 function = reinterpret_cast<F5>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
      static_cast<int64>(function(a0, a1, a2, a3, a4)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  F6 function = reinterpret_cast<F6>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
      static_cast<int64>(function(a0, a1, a2, a3, a4, a5)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignICall7) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  word a6 = AsForeignWord(arguments[7]);
  F7 function = reinterpret_cast<F7>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
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
typedef word (*PF7)(word, word, word, word, word, word, word);

BEGIN_NATIVE(ForeignPCall0) {
  word address = AsForeignWord(arguments[0]);
  PF0 function = reinterpret_cast<PF0>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function()));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  PF1 function = reinterpret_cast<PF1>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  PF2 function = reinterpret_cast<PF2>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0, a1)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  PF3 function = reinterpret_cast<PF3>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(function(a0, a1, a2)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  PF4 function = reinterpret_cast<PF4>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
      static_cast<int64>(function(a0, a1, a2, a3)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  PF5 function = reinterpret_cast<PF5>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
      static_cast<int64>(function(a0, a1, a2, a3, a4)));
}
END_NATIVE()

BEGIN_NATIVE(ForeignPCall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  PF6 function = reinterpret_cast<PF6>(address);
  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(
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
typedef void (*VF7)(word, word, word, word, word, word, word);

BEGIN_NATIVE(ForeignVCall0) {
  word address = AsForeignWord(arguments[0]);
  VF0 function = reinterpret_cast<VF0>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function());
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall1) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  VF1 function = reinterpret_cast<VF1>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall2) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  VF2 function = reinterpret_cast<VF2>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall3) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  VF3 function = reinterpret_cast<VF3>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1, a2));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall4) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  VF4 function = reinterpret_cast<VF4>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1, a2, a3));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall5) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  VF5 function = reinterpret_cast<VF5>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1, a2, a3, a4));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall6) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  VF6 function = reinterpret_cast<VF6>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1, a2, a3, a4, a5));
}
END_NATIVE()

BEGIN_NATIVE(ForeignVCall7) {
  word address = AsForeignWord(arguments[0]);
  word a0 = AsForeignWord(arguments[1]);
  word a1 = AsForeignWord(arguments[2]);
  word a2 = AsForeignWord(arguments[3]);
  word a3 = AsForeignWord(arguments[4]);
  word a4 = AsForeignWord(arguments[5]);
  word a5 = AsForeignWord(arguments[6]);
  word a6 = AsForeignWord(arguments[7]);
  VF7 function = reinterpret_cast<VF7>(address);
  EVALUATE_FFI_CALL_AND_RETURN_VOID(function(a0, a1, a2, a3, a4, a5, a6));
}
END_NATIVE()

typedef int (*I64F0)();
typedef int (*I64F1)(word);
typedef int (*I64F2)(word, word);
typedef int (*I64F3)(word, word, word);
typedef int (*I64F4)(word, word, word, word);
typedef int (*I64F5)(word, word, word, word, word);
typedef int (*I64F6)(word, word, word, word, word, word);
typedef int (*I64F7)(word, word, word, word, word, word, word);

// This enum should match ForeignFunctionReturnType in ffi.dart.
enum {
  FFI_RET_POINTER = 0,
  FFI_RET_INT32,
  FFI_RET_INT64,
  FFI_RET_FLOAT32,
  FFI_RET_FLOAT64,
  FFI_RET_VOID
};

// This enum should match ForeignFunctionArgumentType in ffi.dart.
enum {
  FFI_POINTER = 0,
  FFI_INT32,
  FFI_INT64,
  FFI_FLOAT32,
  FFI_FLOAT64
};

#if defined(DARTINO_TARGET_ARM) || defined(DARTINO_TARGET_IA32)

static void PushFloat(Vector<word>* v, float f) {
  v->PushBack(*reinterpret_cast<word*>(&f));
}

static void PushDouble(Vector<word>* v, double d) {
  word* src = reinterpret_cast<word*>(&d);
  v->PushBack(src[0]);
  v->PushBack(src[1]);
}

#endif  // defined(DARTINO_TARGET_ARM) || defined(DARTINO_TARGET_IA32)

#if defined(DARTINO_TARGET_ARM)

extern "C" {
  void FfiBridge(word* regular, int regularSize, word* stack, int stackSize,
    word* vfp, int vfpSize, word foreign);
}

typedef word (*P_BRIDGE)(word*, int, word*, int, word*, int, word);
typedef int32 (*I32_BRIDGE)(word*, int, word*, int, word*, int, word);
typedef int64 (*I64_BRIDGE)(word*, int, word*, int, word*, int, word);
typedef float (*F32_BRIDGE)(word*, int, word*, int, word*, int, word);
typedef double (*F64_BRIDGE)(word*, int, word*, int, word*, int, word);
typedef void (*V_BRIDGE)(word*, int, word*, int, word*, int, word);

class FFIFrameBuilder {
 public:
  FFIFrameBuilder():
    nextCoreRegister(0), floatingPointGap(-1) {}

  void WordArgument(word v) {
    if (nextCoreRegister < kLastCoreRegister) {
      registerArgs.PushBack(v);
      nextCoreRegister += 1;
    } else {
      stackArgs.PushBack(v);
    }
  }

  void Int64Argument(int64 v) {
    if (nextCoreRegister & 1) {
      // Skip register for alignment.
      registerArgs.PushBack(0);
      nextCoreRegister += 1;
    }
    if (nextCoreRegister + 2 <= kLastCoreRegister) {
      registerArgs.PushBack(v & 0xffffffff);
      registerArgs.PushBack(v >> 32);
      nextCoreRegister += 2;
    } else {
      // Once we touch the stack, no registers are used.
      nextCoreRegister = kLastCoreRegister;
      // Pad for alignment.
      if (stackArgs.size() & 1) {
        stackArgs.PushBack(0);
      }
      stackArgs.PushBack(v & 0xffffffff);
      stackArgs.PushBack(v >> 32);
    }
  }

#if defined(DARTINO_TARGET_ARM_HARDFLOAT)

  void Float32Argument(float v) {
    word w = *reinterpret_cast<word*>(&v);
    // First try to fill in the gap that might be left behind.
    if (floatingPointGap >= 0) {
      floatingPointArgs[floatingPointGap] = w;
      floatingPointGap = -1;
    // Failing that - any registers still available.
    } else if (floatingPointArgs.size() < kLastFloatingPointRegister) {
      floatingPointArgs.PushBack(w);
    // Lastly go to the stack.
    } else {
      stackArgs.PushBack(w);
    }
  }

  void Float64Argument(double v) {
    if (floatingPointArgs.size() & 1) {
      // Padding creates a gap in register allocation.
      floatingPointGap = floatingPointArgs.size();
      PushFloat(&floatingPointArgs, 0.0);
    }
    if (floatingPointArgs.size() + 2 <= kLastFloatingPointRegister) {
      PushDouble(&floatingPointArgs, v);
    } else {
      // Pad for alignment.
      if (stackArgs.size() & 1) {
        stackArgs.PushBack(0);
      }
      PushDouble(&stackArgs, v);
    }
  }
#elif defined(DARTINO_TARGET_ARM_SOFTFLOAT)

  void Float32Argument(float v) {
    word w = *reinterpret_cast<word*>(&v);
    if (nextCoreRegister < kLastCoreRegister) {
      registerArgs.PushBack(w);
      nextCoreRegister += 1;
    } else {
      stackArgs.PushBack(w);
    }
  }

  void Float64Argument(double v) {
    if (nextCoreRegister & 1) {
      // Skip register for alignment.
      registerArgs.PushBack(0);
      nextCoreRegister += 1;
    }
    if (nextCoreRegister + 2 <= kLastCoreRegister) {
      PushDouble(&registerArgs, v);
      nextCoreRegister += 2;
    } else {
      // Pad for alignment.
      if (stackArgs.size() & 1) {
        stackArgs.PushBack(0);
      }
      PushDouble(&stackArgs, v);
    }
  }
#else
#error \
  "Define either DARTINO_TARGET_ARM_HARDFLOAT or DARTINO_TARGET_ARM_SOFTFLOAT"
#endif  // DARTINO_TARGET_ARM_HARDFLOAT
  void Build() {
    // Round floating point args to pairs.
    if (floatingPointArgs.size() & 1) {
      PushFloat(&floatingPointArgs, 0.0);
    }
  }

  word PointerCall(word address) {
    return reinterpret_cast<P_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

  void VoidCall(word address) {
    reinterpret_cast<V_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

  int IntCall(word address) {
    return reinterpret_cast<I32_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

  int64 Int64Call(word address) {
    return reinterpret_cast<I64_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

  float Float32Call(word address) {
    return reinterpret_cast<F32_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

  double Float64Call(word address) {
    return reinterpret_cast<F64_BRIDGE>(FfiBridge)(registerArgs.Data(),
      registerArgs.size(), stackArgs.Data(), stackArgs.size(),
      floatingPointArgs.Data(), floatingPointArgs.size(), address);
  }

 private:
  const size_t kLastCoreRegister = 4;
  const size_t kLastFloatingPointRegister = 16;
  Vector<word> registerArgs, stackArgs;
  Vector<word> floatingPointArgs;
  size_t nextCoreRegister;
  int floatingPointGap;  // A vacant place in floatingPointArgs due to padding.
};

#elif defined(DARTINO_TARGET_IA32)

extern "C" {
  void FfiBridge(word* stack, int stackSize, word foreign);
}

typedef word (*P_BRIDGE)(word*, int, word);
typedef int32 (*I32_BRIDGE)(word*, int, word);
typedef int64 (*I64_BRIDGE)(word*, int, word);
typedef float (*F32_BRIDGE)(word*, int, word);
typedef double (*F64_BRIDGE)(word*, int, word);
typedef void (*V_BRIDGE)(word*, int, word);

class FFIFrameBuilder {
 public:
  void WordArgument(word v) {
    stackArgs.PushBack(v);
  }

  void Int64Argument(int64 v) {
    stackArgs.PushBack(v & 0xffffffff);
    stackArgs.PushBack(v >> 32);
  }

  void Float32Argument(float v) {
    PushFloat(&stackArgs, v);
  }

  void Float64Argument(double v) {
    PushDouble(&stackArgs, v);
  }

  void Build() {}

  word PointerCall(word address) {
    return reinterpret_cast<P_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

  void VoidCall(word address) {
    reinterpret_cast<V_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

  int IntCall(word address) {
    return reinterpret_cast<I32_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

  int64 Int64Call(word address) {
    return reinterpret_cast<I64_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

  float Float32Call(word address) {
    return reinterpret_cast<F32_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

  double Float64Call(word address) {
    return reinterpret_cast<F64_BRIDGE>(FfiBridge)(
      stackArgs.Data(), stackArgs.size(), address);
  }

 private:
  Vector<word> stackArgs;
};

#endif  // DARTINO_TARGET_ARM

#if defined(DARTINO_TARGET_ARM) || defined(DARTINO_TARGET_IA32)

BEGIN_NATIVE(ForeignListCall) {
  word address = AsForeignWord(arguments[0]);
  int returnType = AsForeignWord(arguments[1]);
  int size = AsForeignWord(arguments[2]);
  Object* obj = Instance::cast(arguments[3])->GetInstanceField(0);
  Array* args = Array::cast(obj);
  obj = Instance::cast(arguments[4])->GetInstanceField(0);
  Array* types = Array::cast(obj);
  FFIFrameBuilder builder;
  for (int i = 0; i < size; i++) {
    Object* argType = Instance::cast(types->get(i))->GetInstanceField(0);
    word type = AsForeignWord(argType);
    switch (type) {
      case FFI_POINTER:
      case FFI_INT32:
        builder.WordArgument(AsForeignWord(args->get(i)));
        break;
      case FFI_INT64:
        builder.Int64Argument(AsForeignInt64(args->get(i)));
        break;
      case FFI_FLOAT32:
        builder.Float32Argument(Double::cast(args->get(i))->value());
        break;
      case FFI_FLOAT64:
        builder.Float64Argument(Double::cast(args->get(i))->value());
        break;
      default:
        return Failure::wrong_argument_type();
    }
  }
  builder.Build();
  int64 tmp;
  switch (returnType) {
    case FFI_RET_POINTER:
      tmp = builder.PointerCall(address);
      if (Smi::IsValid(tmp)) return Smi::FromWord(tmp);
      return process->NewIntegerWithGC(tmp);
    case FFI_RET_INT32:
      tmp = builder.IntCall(address);
      if (Smi::IsValid(tmp)) return Smi::FromWord(tmp);
      return process->NewIntegerWithGC(tmp);
    case FFI_RET_INT64:
      tmp = builder.Int64Call(address);
      if (Smi::IsValid(tmp)) return Smi::FromWord(tmp);
      return process->NewIntegerWithGC(tmp);
    case FFI_RET_FLOAT32:
      return process->NewDoubleWithGC(builder.Float32Call(address));
    case FFI_RET_FLOAT64:
      return process->NewDoubleWithGC(builder.Float64Call(address));
    case FFI_RET_VOID:
      builder.VoidCall(address);
      return Smi::FromWord(0);
    default:
      return Failure::wrong_argument_type();
  }
}

END_NATIVE()

#else

BEGIN_NATIVE(ForeignListCall) {
  word address = AsForeignWord(arguments[0]);
  int retType = AsForeignWord(arguments[1]);
  int size = AsForeignWord(arguments[2]);
  Object* obj = Instance::cast(arguments[3])->GetInstanceField(0);
  Array* list = Array::cast(obj);
  word a0 = 0, a1 = 0, a2 = 0, a3 = 0, a4 = 0, a5 = 0, a6 = 0;
  // fall-through initialization
  switch (size) {
    case 7:
      a6 = AsForeignWord(list->get(6));
    case 6:
      a5 = AsForeignWord(list->get(5));
    case 5:
      a4 = AsForeignWord(list->get(4));
    case 4:
      a3 = AsForeignWord(list->get(3));
    case 3:
      a2 = AsForeignWord(list->get(2));
    case 2:
      a1 = AsForeignWord(list->get(1));
    case 1:
      a0 = AsForeignWord(list->get(0));
    case 0:
      break;
    default:
      return Failure::index_out_of_bounds();
  }
  if (retType == FFI_RET_INT32) {
    int ret = 0;
    switch (size) {
      case 0:
        ret = reinterpret_cast<F0>(address)();
        break;
      case 1:
        ret = reinterpret_cast<F1>(address)(a0);
        break;
      case 2:
        ret = reinterpret_cast<F2>(address)(a0, a1);
        break;
      case 3:
        ret = reinterpret_cast<F3>(address)(a0, a1, a2);
        break;
      case 4:
        ret = reinterpret_cast<F4>(address)(a0, a1, a2, a3);
        break;
      case 5:
        ret = reinterpret_cast<F5>(address)(a0, a1, a2, a3, a4);
        break;
      case 6:
        ret = reinterpret_cast<F6>(address)(a0, a1, a2, a3, a4, a5);
        break;
      case 7:
        ret = reinterpret_cast<F7>(address)(a0, a1, a2, a3, a4, a5, a6);
        break;
    }
    EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(ret));
  } else if (retType == FFI_RET_INT64) {
    int64 ret = 0;
    switch (size) {
      case 0:
        ret = reinterpret_cast<I64F0>(address)();
        break;
      case 1:
        ret = reinterpret_cast<I64F1>(address)(a0);
        break;
      case 2:
        ret = reinterpret_cast<I64F2>(address)(a0, a1);
        break;
      case 3:
        ret = reinterpret_cast<I64F3>(address)(a0, a1, a2);
        break;
      case 4:
        ret = reinterpret_cast<I64F4>(address)(a0, a1, a2, a3);
        break;
      case 5:
        ret = reinterpret_cast<I64F5>(address)(a0, a1, a2, a3, a4);
        break;
      case 6:
        ret = reinterpret_cast<I64F6>(address)(a0, a1, a2, a3, a4, a5);
        break;
      case 7:
        ret = reinterpret_cast<I64F7>(address)(a0, a1, a2, a3, a4, a5, a6);
        break;
    }
    EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(ret));
  } else if (retType == FFI_RET_POINTER) {
    word ret = 0;
    switch (size) {
      case 0:
        ret = reinterpret_cast<PF0>(address)();
        break;
      case 1:
        ret = reinterpret_cast<PF1>(address)(a0);
        break;
      case 2:
        ret = reinterpret_cast<PF2>(address)(a0, a1);
        break;
      case 3:
        ret = reinterpret_cast<PF3>(address)(a0, a1, a2);
        break;
      case 4:
        ret = reinterpret_cast<PF4>(address)(a0, a1, a2, a3);
        break;
      case 5:
        ret = reinterpret_cast<PF5>(address)(a0, a1, a2, a3, a4);
        break;
      case 6:
        ret = reinterpret_cast<PF6>(address)(a0, a1, a2, a3, a4, a5);
        break;
      case 7:
        ret = reinterpret_cast<PF7>(address)(a0, a1, a2, a3, a4, a5, a6);
        break;
    }
    EVALUATE_FFI_CALL_AND_RETURN_AND_GC(static_cast<int64>(ret));
  } else if (retType == FFI_RET_VOID) {
    switch (size) {
      case 0:
        reinterpret_cast<VF0>(address)();
        break;
      case 1:
        reinterpret_cast<VF1>(address)(a0);
        break;
      case 2:
        reinterpret_cast<VF2>(address)(a0, a1);
        break;
      case 3:
        reinterpret_cast<VF3>(address)(a0, a1, a2);
        break;
      case 4:
        reinterpret_cast<VF4>(address)(a0, a1, a2, a3);
        break;
      case 5:
        reinterpret_cast<VF5>(address)(a0, a1, a2, a3, a4);
        break;
      case 6:
        reinterpret_cast<VF6>(address)(a0, a1, a2, a3, a4, a5);
        break;
      case 7:
        reinterpret_cast<VF7>(address)(a0, a1, a2, a3, a4, a5, a6);
        break;
    }
    return Smi::FromWord(0);
  } else {  // TODO(dmitryolsh) : float32 return type
    return Failure::wrong_argument_type();
  }
}
END_NATIVE()

#endif  // defined(DARTINO_TARGET_ARM) || defined(DARTINO_TARGET_IA32)

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

  EVALUATE_FFI_CALL_AND_RETURN_AND_GC(function(a0, a1, a2));
}
END_NATIVE()

#define DEFINE_FOREIGN_ACCESSORS_INTEGER(suffix, type)                    \
                                                                          \
  BEGIN_LEAF_NATIVE(ForeignGet##suffix) {                                      \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    return process->ToInteger(*address);                                  \
  }                                                                       \
  END_NATIVE()                                                            \
                                                                          \
  BEGIN_LEAF_NATIVE(ForeignSet##suffix) {                                      \
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
  BEGIN_LEAF_NATIVE(ForeignGet##suffix) {                                      \
    type* address = reinterpret_cast<type*>(AsForeignWord(arguments[0])); \
    return process->NewDouble(static_cast<double>(*address));             \
  }                                                                       \
  END_NATIVE()                                                            \
                                                                          \
  BEGIN_LEAF_NATIVE(ForeignSet##suffix) {                                      \
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
