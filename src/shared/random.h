// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_RANDOM_H_
#define SRC_SHARED_RANDOM_H_

#include "src/shared/globals.h"

namespace fletch {

// This class implements a LCG (Linear Congruential Generator) pseudo random
// number generator.
//
// It has the following properties:
//  - it has only a 32-bit state
//  - it is guaranteed to cycle through every possible 32-bit integer
class RandomLCG {
 public:
  static const uint64 A = 1103515245;
  static const uint64 C = 12345;

  explicit RandomLCG(uint32 seed) : state_(seed) {}

  uint32 NextUInt32() {
    uint64 state = state_;
    state_ = static_cast<uint32>(state * A + C);
    return state_;
  }

 private:
  uint32 state_;
};

}  // namespace fletch

#endif  // SRC_SHARED_RANDOM_H_
