// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ATOMIC_H_
#define SRC_SHARED_ATOMIC_H_

#if defined(FLETCH_TARGET_OS_LK)
#include "src/shared/atomic_gcc_intrinsics.h"
#else
#include "src/shared/atomic_cpp11.h"
#endif

#endif  // SRC_SHARED_ATOMIC_H_
