// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_DARTINO_H_
#define SRC_SHARED_DARTINO_H_

#include "src/shared/globals.h"

namespace dartino {

// Dartino is a helper class used to call system wide functions such as
// initialization. The definition of the class is shared between the
// compiler and the VM, but both of these have their own implementation.
class Dartino {
 public:
  // Initialize Dartino and all its subsystems.
  static void Setup();

  static void TearDown();

 private:
  // Make sure that this class can not ever be instantiated. All its methods
  // should be static class methods.
  DISALLOW_ALLOCATION();
  DISALLOW_IMPLICIT_CONSTRUCTORS(Dartino);
};

}  // namespace dartino

#endif  // SRC_SHARED_DARTINO_H_
