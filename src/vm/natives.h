// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_NATIVES_H_
#define SRC_VM_NATIVES_H_

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

typedef Object* (*NativeFunction)(Process*, Arguments);

#define NATIVE(n) \
  extern "C" Object* Native_##n(Process* process, Arguments arguments)

#define N(e, c, n) NATIVE(e);
NATIVES_DO(N)
#undef N

}  // namespace fletch

#endif  // SRC_VM_NATIVES_H_
