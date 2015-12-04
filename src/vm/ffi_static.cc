// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_LK) || defined(FLETCH_TARGET_OS_CMSIS)

#ifdef FLETCH_ENABLE_FFI

#include "src/vm/ffi.h"
#include "src/vm/natives.h"
#include "src/vm/process.h"
#include "src/shared/assert.h"

#include "include/static_ffi.h"

extern "C" FletchStaticFFISymbol fletch_ffi_table;

namespace fletch {

void ForeignFunctionInterface::Setup() {}

void ForeignFunctionInterface::TearDown() {}

void ForeignFunctionInterface::AddDefaultSharedLibrary(const char* library) {
  FATAL("fletch vm was built without dynamic-libary FFI support.");
}

void* ForeignFunctionInterface::LookupInDefaultLibraries(const char* symbol) {
  UNIMPLEMENTED();
  return NULL;
}

DefaultLibraryEntry* ForeignFunctionInterface::libraries_ = NULL;
Mutex* ForeignFunctionInterface::mutex_ = NULL;

NATIVE(ForeignLibraryGetFunction) {
  word address = AsForeignWord(arguments[0]);
  if (address != 0) return Failure::index_out_of_bounds();
  char* name = AsForeignString(arguments[1]);
  for (FletchStaticFFISymbol* entry = &fletch_ffi_table; entry->name != NULL;
       entry++) {
    if (strcmp(name, entry->name) == 0) {
      free(name);
      return process->ToInteger(reinterpret_cast<intptr_t>(entry->ptr));
    }
  }
  free(name);
  return Failure::index_out_of_bounds();
}

NATIVE(ForeignLibraryLookup) {
  char* library = AsForeignString(arguments[0]);
  if (library != NULL) {
    free(library);
    return Failure::index_out_of_bounds();
  }
  return Smi::FromWord(0);
}

NATIVE(ForeignLibraryClose) {
  word address = AsForeignWord(arguments[0]);
  if (address != 0) {
    return Failure::index_out_of_bounds();
  }
  return Smi::FromWord(0);
}

NATIVE(ForeignLibraryBundlePath) {
  UNIMPLEMENTED();
  return Smi::FromWord(0);
}

NATIVE(ForeignErrno) {
  UNIMPLEMENTED();
  return Smi::FromWord(0);
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_FFI

#endif  // defined(FLETCH_TARGET_OS_LK) || defined(FLETCH_TARGET_OS_CMSIS)
