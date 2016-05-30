// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_ASSEMBLER_H_
#define SRC_VM_ASSEMBLER_H_

#include "src/shared/globals.h"

#ifdef DARTINO32

#if defined(DARTINO_TARGET_ARM)
#include "src/vm/assembler_arm.h"
#elif defined(DARTINO_TARGET_MIPS)
#include "src/vm/assembler_mips.h"
#else
#include "src/vm/assembler_x86.h"
#endif

#else

// TODO(ager): Add arm64 assembler as well.
#include "src/vm/assembler_x64.h"

#endif

#endif  // SRC_VM_ASSEMBLER_H_
