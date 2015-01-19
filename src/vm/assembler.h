// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_H_
#define SRC_VM_ASSEMBLER_H_

#include "src/shared/globals.h"

#ifdef FLETCH32
// TODO(kasperl): Of course it's wrong to assume that all 32-bit machines
// are x86, but this is the way it is for now. Will fix.
#include "src/vm/assembler_x86.h"
#else
#include "src/vm/assembler_x64.h"
#endif

#endif  // SRC_VM_ASSEMBLER_H_
