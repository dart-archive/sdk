// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_INTRINSICS_H_
#define SRC_VM_INTRINSICS_H_

namespace fletch {

#define INTRINSICS_DO(V)      \
  V(GetField)                 \
  V(SetField)                 \
  V(ListIndexGet)             \
  V(ListIndexSet)             \
  V(ListLength)

#define DECLARE_EXTERN(name) \
  extern "C" void Intrinsic_##name() __attribute__((weak));
INTRINSICS_DO(DECLARE_EXTERN)
#undef DECLARE_EXTERN

}  // namespace fletch

#endif  // SRC_VM_INTRINSICS_H_
