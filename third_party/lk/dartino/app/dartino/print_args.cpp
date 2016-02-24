// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>

#include "src/vm/intrinsics.h"

namespace dartino {

extern "C" void InterpreterMethodEntry(void);

extern "C" void PrintArgs(void *buffer) {
  printf("COMMANDARGS\n");
#define PRINT_INTRINSIC(_name) \
  printf("-i " #_name "=%p ", &Intrinsic_##_name);
  INTRINSICS_DO(PRINT_INTRINSIC)
#undef PRINT_INTRINSIC
  printf("%p\n", &InterpreterMethodEntry);
  printf("%p\n", buffer);
}

}  // namespace dartino
