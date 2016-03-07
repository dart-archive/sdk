// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(DARTINO_TARGET_OS_POSIX)

#ifdef DARTINO_ENABLE_FFI

#include "src/vm/ffi.h"

#include <dlfcn.h>
#include <errno.h>
#include <libgen.h>
#include <sys/param.h>

#include "src/shared/platform.h"
#include "src/shared/utils.h"

#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace dartino {

char* ForeignUtils::DirectoryName(char* path, char* buffer, size_t len) {
  strncpy(buffer, path, len);
  buffer[len - 1] = '\0';
  return dirname(buffer);
}

class DefaultLibraryEntry {
 public:
  DefaultLibraryEntry(void* handle, DefaultLibraryEntry* next)
      : handle_(handle), next_(next) {}

  ~DefaultLibraryEntry() { dlclose(handle_); }

  void* handle() const { return handle_; }
  DefaultLibraryEntry* next() const { return next_; }

  void append(DefaultLibraryEntry* entry) {
    if (next_ == NULL) {
      next_ = entry;
    } else {
      next_->append(entry);
    }
  }

 private:
  void* handle_;
  DefaultLibraryEntry* next_;
};

DefaultLibraryEntry* ForeignFunctionInterface::libraries_ = NULL;
Mutex* ForeignFunctionInterface::mutex_ = NULL;

void ForeignFunctionInterface::Setup() { mutex_ = Platform::CreateMutex(); }

void ForeignFunctionInterface::TearDown() {
  DefaultLibraryEntry* current = libraries_;
  while (current != NULL) {
    DefaultLibraryEntry* next = current->next();
    delete current;
    current = next;
  }
  delete mutex_;
}

bool ForeignFunctionInterface::AddDefaultSharedLibrary(const char* library) {
  ScopedLock lock(mutex_);
  void* handle = dlopen(library, RTLD_LOCAL | RTLD_LAZY);
  if (handle != NULL) {
    // We have to maintain the insertion order (see dartino_api.h).
    if (libraries_ == NULL) {
      libraries_ = new DefaultLibraryEntry(handle, libraries_);
    } else {
      libraries_->append(new DefaultLibraryEntry(handle, libraries_));
    }
    return true;
  }
  return false;
}

void* ForeignFunctionInterface::LookupInDefaultLibraries(const char* symbol) {
  ScopedLock lock(mutex_);
  for (DefaultLibraryEntry* current = libraries_; current != NULL;
       current = current->next()) {
    void* result = dlsym(current->handle(), symbol);
    if (result != NULL) return result;
  }
  return NULL;
}

void FinalizeForeignLibrary(HeapObject* foreign, Heap* heap) {
  word address = AsForeignWord(foreign);
  void* handle = reinterpret_cast<void*>(address);
  ASSERT(handle != NULL);
  if (dlclose(handle) != 0) {
    Print::Error("Failed to close handle: %s\n", dlerror());
  }
}

BEGIN_LEAF_NATIVE(ForeignLibraryLookup) {
  char* library = AsForeignString(arguments[0]);
  bool global = arguments[1]->IsTrue();
  int flags = (global ? RTLD_GLOBAL : RTLD_LOCAL) | RTLD_LAZY;
  void* result = dlopen(library, flags);
  if (result == NULL) {
    Print::Error("Failed libary lookup(%s): %s\n", library, dlerror());
  }
  free(library);
  if (result == NULL) return Failure::index_out_of_bounds();
  Object* handle = process->NewInteger(reinterpret_cast<intptr_t>(result));
  if (handle->IsRetryAfterGCFailure()) return handle;
  process->RegisterFinalizer(HeapObject::cast(handle), FinalizeForeignLibrary);
  return handle;
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignLibraryGetFunction) {
  word address = AsForeignWord(arguments[0]);
  void* handle = reinterpret_cast<void*>(address);
  char* name = AsForeignString(arguments[1]);
  bool default_lookup = handle == NULL;
  if (default_lookup) handle = dlopen(NULL, RTLD_LOCAL | RTLD_LAZY);
  void* result = dlsym(handle, name);
  if (default_lookup) dlclose(handle);
  if (result == NULL) {
    result = ForeignFunctionInterface::LookupInDefaultLibraries(name);
  }
  free(name);
  return result != NULL ? process->ToInteger(reinterpret_cast<intptr_t>(result))
                        : Failure::index_out_of_bounds();
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignLibraryBundlePath) {
  char* library = AsForeignString(arguments[0]);
  char executable[MAXPATHLEN + 1];
  GetPathOfExecutable(executable, sizeof(executable));
  char buffer[MAXPATHLEN + 1];
  char* directory =
      ForeignUtils::DirectoryName(executable, buffer, sizeof(buffer));
  // dirname on linux may mess with the content of the buffer, so we use a fresh
  // buffer for the result. If anybody cares this can be optimized by manually
  // writing the strings other than dirname to the executable buffer.
  char result[MAXPATHLEN + 1];
  int wrote = snprintf(result, MAXPATHLEN + 1, "%s%s%s%s", directory,
                       ForeignUtils::kLibBundlePrefix, library,
                       ForeignUtils::kLibBundlePostfix);
  free(library);
  if (wrote > MAXPATHLEN) {
    return Failure::index_out_of_bounds();
  }
  return process->NewStringFromAscii(List<const char>(result, strlen(result)));
}
END_NATIVE()

BEGIN_LEAF_NATIVE(ForeignErrno) { return Smi::FromWord(errno); }
END_NATIVE()

}  // namespace dartino

#endif  // DARTINO_ENABLE_FFI

#endif  // defined(DARTINO_TARGET_OS_POSIX)
