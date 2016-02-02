// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_NATIVES_H_
#define SRC_VM_NATIVES_H_

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/natives.h"

namespace fletch {

// Forward declarations.
class Assembler;
class Object;
class OneByteString;
class Process;
class TwoByteString;

// TODO(kasperl): Move this elsewhere.
char* AsForeignString(Object* object);

// Wrapper for arguments to native functions, where argument indexing is
// growing.
class Arguments {
 public:
  explicit Arguments(Object** raw) : raw_(raw) {}

  Object* operator[](word index) const { return raw_[-index]; }

 private:
  Object** raw_;
};

// A NativeVerifier is stack allocated at the start of a native and
// destructed at the end of the native. In debug mode, the verifier
// tracks allocations and the destructor verifies that the native only
// performed one allocation.
#ifdef DEBUG
class NativeVerifier {
 public:
  explicit NativeVerifier(Process* process);
  ~NativeVerifier();

  void RegisterAllocation() { ++allocation_count_; }

 private:
  Process* process_;
  int allocation_count_;
};
#else
class NativeVerifier {
 public:
  explicit NativeVerifier(Process* process) {}
  void RegisterAllocation() { UNREACHABLE(); }
};
#endif

typedef Object* (*NativeFunction)(Process*, Arguments);

#define DECLARE_NATIVE(n) \
  extern "C" Object* Native_##n(Process* process, Arguments arguments);

#define BEGIN_NATIVE(n)                                                  \
  extern "C" Object* Native_##n(Process* process, Arguments arguments) { \
    NativeVerifier verifier(process);

#define BEGIN_DETACHABLE_NATIVE(n)                                      \
    BEGIN_NATIVE(n)                                                     \
    static_assert(kIsDetachable_##n, "Incorrect use of natives macro");

#define END_NATIVE() }

#define N(e, c, n, d) DECLARE_NATIVE(e)
NATIVES_DO(N)
#undef N

}  // namespace fletch

#endif  // SRC_VM_NATIVES_H_
