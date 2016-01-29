// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_WIN)

#ifdef FLETCH_ENABLE_FFI

#include "src/vm/ffi.h"

#include <Windows.h>

#include "src/shared/platform.h"
#include "src/vm/natives.h"
#include "src/vm/object.h"
#include "src/vm/process.h"

namespace fletch {

const char* ForeignUtils::kLibBundlePrefix = "\\lib\\";
const char* ForeignUtils::kLibBundlePostfix = ".dll";

char* ForeignUtils::DirectoryName(char* path, char *buffer, size_t len) {
  TCHAR *file_name_ptr;
  if (GetFullPathName(path, len, buffer, &file_name_ptr) == 0) {
    buffer[0] = '\0';
    return buffer;
  }
  if (file_name_ptr != NULL) {
    // If file_name_ptr is not NULL, it points to the beginning of the
    // non-directory part of path, which always is preceded by an '\'.
    // So we need to terminate the string one character earlier to get to
    // the directory part.
    *(file_name_ptr - 1) = '\0';
  }
  return buffer;
}

class DefaultLibraryEntry {
 public:
  DefaultLibraryEntry(HMODULE handle, DefaultLibraryEntry* next)
      : handle_(handle), next_(next) {}

  ~DefaultLibraryEntry() { FreeLibrary(handle_); }

  HMODULE handle() const { return handle_; }
  DefaultLibraryEntry* next() const { return next_; }

  void append(DefaultLibraryEntry* entry) {
    if (next_ == NULL) {
      next_ = entry;
    } else {
      next_->append(entry);
    }
  }

 private:
  HMODULE handle_;
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

  HMODULE handle = LoadLibrary(library);

  if (handle != NULL) {
    // We have to maintain the insertion order (see fletch_api.h).
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
    FARPROC result = GetProcAddress(current->handle(), symbol);
    if (result != NULL) return static_cast<void*>(result);
  }
  return NULL;
}

void FinalizeForeignLibrary(HeapObject* foreign, Heap* heap) {
  word address = AsForeignWord(foreign);
  HMODULE handle = reinterpret_cast<HMODULE>(address);
  ASSERT(handle != NULL);
  if (!FreeLibrary(handle) == 0) {
    Print::Error("Failed to close handle: %d\n", GetLastError());
  }
}

BEGIN_NATIVE(ForeignLibraryLookup) {
  char* library = AsForeignString(arguments[0]);
  HMODULE handle = LoadLibrary(library);
  if (handle == NULL) {
    Print::Error("Failed libary lookup(%s): %d\n", library, GetLastError());
  }
  free(library);
  if (handle == NULL) return Failure::index_out_of_bounds();
  Object* result = process->NewInteger(reinterpret_cast<intptr_t>(handle));
  if (result->IsRetryAfterGCFailure()) return result;
  process->RegisterFinalizer(HeapObject::cast(result), FinalizeForeignLibrary);
  return result;
}
END_NATIVE()

BEGIN_NATIVE(ForeignLibraryGetFunction) {
  word address = AsForeignWord(arguments[0]);
  HMODULE handle = reinterpret_cast<HMODULE>(address);
  char* name = AsForeignString(arguments[1]);
  bool default_lookup = handle == NULL;
  if (default_lookup) handle = GetModuleHandle(NULL);
  void* result = static_cast<void*>(GetProcAddress(handle, name));
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
  char buffer[MAXPATHLEN + 1];
  char* directory =
      ForeignUtils::DirectoryName(executable, buffer, sizeof(buffer));
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

BEGIN_NATIVE(ForeignErrno) { return Smi::FromWord(GetLastError()); }
END_NATIVE()

}  // namespace fletch

#endif  // FLETCH_ENABLE_FFI

#endif  // defined(FLETCH_TARGET_OS_WIN)
