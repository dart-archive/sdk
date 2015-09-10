// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/test_case.h"
#include "src/shared/random.h"

namespace fletch {

// Only run this test in release mode, since it is compute intensive.
#ifndef DEBUG

TEST_CASE(RandomLCG_MaximumPeriod) {
  RandomLCG rng(0);

  uint32 start = rng.NextUInt32();
  uint32 current = start;
  uint64 counter = 0;
  do {
    counter++;
    current = rng.NextUInt32();
  } while (start != current);

  ASSERT(counter == UINT64_C(0x100000000));
}

#endif

}  // namespace fletch
