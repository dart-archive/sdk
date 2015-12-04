// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_FFI_H_
#define SRC_VM_FFI_H_

#include "src/shared/globals.h"
#include "src/shared/natives.h"

namespace fletch {

class DefaultLibraryEntry;
class Mutex;

class ForeignFunctionInterface {
 public:
  static void Setup();
  static void TearDown();
  static void AddDefaultSharedLibrary(const char* library);
  static void* LookupInDefaultLibraries(const char* symbol);

 private:
  static DefaultLibraryEntry* libraries_;
  static Mutex* mutex_;
};

#ifdef FLETCH_ENABLE_FFI
// Platform specific ffi constants and methods.
class ForeignUtils {
 public:
  // We construct default bundle library paths from a prefix and a postfix.
  static const char* kLibBundlePrefix;
  static const char* kLibBundlePostfix;

  // In preparation of supporting windows we have a function for this.
  static char* DirectoryName(char* path);
};

#endif  // FLETCH_ENABLE_FFI

}  // namespace fletch

#endif  // SRC_VM_FFI_H_
