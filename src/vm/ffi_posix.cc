// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_POSIX)

#ifdef FLETCH_ENABLE_FFI

#include "src/vm/ffi.h"

#include <dlfcn.h>
#include <errno.h>
#include <libgen.h>
#include <sys/param.h>

#include "src/shared/platform.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

char* ForeignUtils::DirectoryName(char* path) { return dirname(path); }

class DefaultLibraryEntry {
 public:
  DefaultLibraryEntry(char* library, DefaultLibraryEntry* next)
      : library_(library), next_(next) {}

  ~DefaultLibraryEntry() { free(library_); }

  const char* library() const { return library_; }
  DefaultLibraryEntry* next() const { return next_; }

 private:
  char* library_;
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

void ForeignFunctionInterface::AddDefaultSharedLibrary(const char* library) {
  ScopedLock lock(mutex_);
  libraries_ = new DefaultLibraryEntry(strdup(library), libraries_);
}

static void* PerformForeignLookup(const char* library, const char* name) {
  void* handle = dlopen(library, RTLD_LOCAL | RTLD_LAZY);
  if (handle == NULL) return NULL;
  void* result = dlsym(handle, name);
  if (dlclose(handle) != 0) return NULL;
  return result;
}

void* ForeignFunctionInterface::LookupInDefaultLibraries(const char* symbol) {
  ScopedLock lock(mutex_);
  for (DefaultLibraryEntry* current = libraries_; current != NULL;
       current = current->next()) {
    void* result = PerformForeignLookup(current->library(), symbol);
    if (result != NULL) return result;
  }
  return NULL;
}

BEGIN_NATIVE(ForeignLibraryLookup) {
  char* library = AsForeignString(arguments[0]);
  bool global = arguments[1]->IsTrue();
  int flags = (global ? RTLD_GLOBAL : RTLD_LOCAL) | RTLD_LAZY;
  void* result = dlopen(library, flags);
  if (result == NULL) {
    fprintf(stderr, "Failed libary lookup(%s): %s\n", library, dlerror());
  }
  free(library);
  return result != NULL ? process->ToInteger(reinterpret_cast<intptr_t>(result))
                        : Failure::index_out_of_bounds();
}
END_NATIVE()

BEGIN_NATIVE(ForeignLibraryGetFunction) {
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

BEGIN_NATIVE(ForeignLibraryBundlePath) {
  char* library = AsForeignString(arguments[0]);
  char executable[MAXPATHLEN + 1];
  GetPathOfExecutable(executable, sizeof(executable));
  char* directory = ForeignUtils::DirectoryName(executable);
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

BEGIN_NATIVE(ForeignLibraryClose) {
  word address = AsForeignWord(arguments[0]);
  void* handle = reinterpret_cast<void*>(address);
  if (dlclose(handle) != 0) {
    fprintf(stderr, "Failed to close handle: %s\n", dlerror());
    return Failure::index_out_of_bounds();
  }
  return NULL;
}
END_NATIVE()

BEGIN_NATIVE(ForeignErrno) { return Smi::FromWord(errno); }
END_NATIVE()

}  // namespace fletch

#endif  // FLETCH_ENABLE_FFI

#endif  // defined(FLETCH_TARGET_OS_POSIX)
