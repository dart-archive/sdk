// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_LK) || defined(DARTINO_TARGET_OS_CMSIS)

#ifdef DARTINO_ENABLE_FFI

#include "src/vm/ffi.h"
#include "src/vm/natives.h"
#include "src/vm/process.h"
#include "src/shared/assert.h"

#include "include/static_ffi.h"

extern "C" DartinoStaticFFISymbol dartino_ffi_table;

namespace dartino {

void ForeignFunctionInterface::Setup() {}

void ForeignFunctionInterface::TearDown() {}

bool ForeignFunctionInterface::AddDefaultSharedLibrary(const char* library) {
  return false;
}

void* ForeignFunctionInterface::LookupInDefaultLibraries(const char* symbol) {
  UNIMPLEMENTED();
  return NULL;
}

DartinoStaticFFISymbol intrinsic_ffi_table[] = {
  {"strlen", reinterpret_cast<const void*>(strlen)},
  {NULL, NULL}
};

DefaultLibraryEntry* ForeignFunctionInterface::libraries_ = NULL;
Mutex* ForeignFunctionInterface::mutex_ = NULL;

static const void* Lookup(DartinoStaticFFISymbol* table, char* name) {
  for (DartinoStaticFFISymbol* entry = table; entry->name != NULL;
       entry++) {
    if (strcmp(name, entry->name) == 0) {
      return entry->ptr;
    }
  }
  return NULL;
}

BEGIN_LEAF_NATIVE(ForeignLibraryGetFunction) {
  word address = AsForeignWord(arguments[0]);
  if (address != 0) return Failure::index_out_of_bounds();
  char* name = AsForeignString(arguments[1]);
  const void* ptr;
  ptr = Lookup(&dartino_ffi_table, name);
  if (ptr == NULL) {
    ptr = Lookup(intrinsic_ffi_table, name);
  }
  free(name);
  if (ptr != NULL) {
    return process->ToInteger(reinterpret_cast<intptr_t>(ptr));
  }
  return Failure::index_out_of_bounds();
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignLibraryLookup) {
  char* library = AsForeignString(arguments[0]);
  if (library != NULL) {
    free(library);
    return Failure::index_out_of_bounds();
  }
  return Smi::FromWord(0);
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignLibraryBundlePath) {
  UNIMPLEMENTED();
  return Smi::FromWord(0);
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignErrno) {
  UNIMPLEMENTED();
  return Smi::FromWord(0);
}
END_NATIVE()

}  // namespace dartino

#endif  // DARTINO_ENABLE_FFI

#endif  // defined(DARTINO_TARGET_OS_LK) || defined(DARTINO_TARGET_OS_CMSIS)
