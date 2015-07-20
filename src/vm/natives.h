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
class String;
class Process;

// TODO(kasperl): Move this elsewhere.
char* AsForeignString(String* value);

typedef Object* (*NativeFunction)(Process*, Object**);

#define NATIVE(n) extern "C" \
  Object* Native_##n(Process* process, Object** arguments)

#define N(e, c, n) \
  NATIVE(e) __attribute__((weak));
NATIVES_DO(N)
#undef N

}  // namespace fletch

#endif  // SRC_VM_NATIVES_H_
