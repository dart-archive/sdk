// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_RANDOM_H_
#define SRC_SHARED_RANDOM_H_

#include "src/shared/globals.h"

namespace fletch {

// This class implements Xorshift+
//
// It has the following properties:
//  - it has 128-bit state
//  - it is guaranteed to cycle through every possible 128-bit state (except 0).
//  - it doesn't systematically fail the BigCrush tests.
//  - on Intel hardware it is slightly faster than Xorshift* and LCG generators.
//  - it doesn't need multiply instructions.  Note that the Cortex M0/M1 has
//    only 32x32->32 bit multiply, no 32x32->64 bit mul instruction.
class RandomXorShift {
 public:
  // Starting at zero would make it fail, and starting with very few bits set
  // is also not good, so we guard against zero seeds.
  explicit RandomXorShift(uint32 seed)
      : s0_(seed ^ 314159265), s1_(271828182) {}

  RandomXorShift() : s0_(314159265), s1_(271828182) {}

  uint32 NextUInt32() {
    uint64 x = s0_;
    uint64 const y = s1_;
    s0_ = y;
    x ^= x << 23;
    x ^= x >> 17;
    x ^= y ^ (y >> 26);
    s1_ = x;
    return x + y;
  }

 private:
  uint64 s0_;
  uint64 s1_;
};

}  // namespace fletch

#endif  // SRC_SHARED_RANDOM_H_
