// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef FLETCH_ENABLE_FFI

#include "src/vm/ffi.h"
#include "src/vm/natives.h"
#include "src/shared/assert.h"

namespace fletch {

void ForeignFunctionInterface::Setup() {
}

void ForeignFunctionInterface::TearDown() {
}

void ForeignFunctionInterface::AddDefaultSharedLibrary(const char* library) {
  FATAL("fletch vm was built without FFI support.");
}

void* ForeignFunctionInterface::LookupInDefaultLibraries(const char* symbol) {
  UNIMPLEMENTED();
  return NULL;
}

DefaultLibraryEntry *ForeignFunctionInterface::libraries_ = NULL;
Mutex *ForeignFunctionInterface::mutex_ = NULL;

#define UNIMPLEMENTED_NATIVE(name) \
  NATIVE(name)  {                  \
    UNIMPLEMENTED();               \
    return NULL;                   \
  }

UNIMPLEMENTED_NATIVE(ForeignLibraryLookup)
UNIMPLEMENTED_NATIVE(ForeignLibraryGetFunction)
UNIMPLEMENTED_NATIVE(ForeignLibraryBundlePath)
UNIMPLEMENTED_NATIVE(ForeignLibraryClose)

UNIMPLEMENTED_NATIVE(ForeignAllocate)
UNIMPLEMENTED_NATIVE(ForeignFree)
UNIMPLEMENTED_NATIVE(ForeignDecreaseMemoryUsage);
UNIMPLEMENTED_NATIVE(ForeignMarkForFinalization)

UNIMPLEMENTED_NATIVE(ForeignBitsPerWord)
UNIMPLEMENTED_NATIVE(ForeignErrno)
UNIMPLEMENTED_NATIVE(ForeignPlatform)
UNIMPLEMENTED_NATIVE(ForeignArchitecture)
UNIMPLEMENTED_NATIVE(ForeignConvertPort)

UNIMPLEMENTED_NATIVE(ForeignICall0)
UNIMPLEMENTED_NATIVE(ForeignICall1)
UNIMPLEMENTED_NATIVE(ForeignICall2)
UNIMPLEMENTED_NATIVE(ForeignICall3)
UNIMPLEMENTED_NATIVE(ForeignICall4)
UNIMPLEMENTED_NATIVE(ForeignICall5)
UNIMPLEMENTED_NATIVE(ForeignICall6)

UNIMPLEMENTED_NATIVE(ForeignPCall0)
UNIMPLEMENTED_NATIVE(ForeignPCall1)
UNIMPLEMENTED_NATIVE(ForeignPCall2)
UNIMPLEMENTED_NATIVE(ForeignPCall3)
UNIMPLEMENTED_NATIVE(ForeignPCall4)
UNIMPLEMENTED_NATIVE(ForeignPCall5)
UNIMPLEMENTED_NATIVE(ForeignPCall6)

UNIMPLEMENTED_NATIVE(ForeignVCall0)
UNIMPLEMENTED_NATIVE(ForeignVCall1)
UNIMPLEMENTED_NATIVE(ForeignVCall2)
UNIMPLEMENTED_NATIVE(ForeignVCall3)
UNIMPLEMENTED_NATIVE(ForeignVCall4)
UNIMPLEMENTED_NATIVE(ForeignVCall5)
UNIMPLEMENTED_NATIVE(ForeignVCall6)

UNIMPLEMENTED_NATIVE(ForeignLCallwLw)

UNIMPLEMENTED_NATIVE(ForeignGetInt8)
UNIMPLEMENTED_NATIVE(ForeignGetInt16)
UNIMPLEMENTED_NATIVE(ForeignGetInt32)
UNIMPLEMENTED_NATIVE(ForeignGetInt64)

UNIMPLEMENTED_NATIVE(ForeignSetInt8)
UNIMPLEMENTED_NATIVE(ForeignSetInt16)
UNIMPLEMENTED_NATIVE(ForeignSetInt32)
UNIMPLEMENTED_NATIVE(ForeignSetInt64)

UNIMPLEMENTED_NATIVE(ForeignGetUint8)
UNIMPLEMENTED_NATIVE(ForeignGetUint16)
UNIMPLEMENTED_NATIVE(ForeignGetUint32)
UNIMPLEMENTED_NATIVE(ForeignGetUint64)

UNIMPLEMENTED_NATIVE(ForeignSetUint8)
UNIMPLEMENTED_NATIVE(ForeignSetUint16)
UNIMPLEMENTED_NATIVE(ForeignSetUint32)
UNIMPLEMENTED_NATIVE(ForeignSetUint64)

UNIMPLEMENTED_NATIVE(ForeignGetFloat32)
UNIMPLEMENTED_NATIVE(ForeignGetFloat64)

UNIMPLEMENTED_NATIVE(ForeignSetFloat32)
UNIMPLEMENTED_NATIVE(ForeignSetFloat64)

}  // namespace fletch

#endif  // not FLETCH_ENABLE_FFI
