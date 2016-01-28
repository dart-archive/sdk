// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/test_case.h"
#include "src/shared/utils.h"

namespace fletch {

TEST_CASE(Minimum) {
  EXPECT_EQ(0, Utils::Minimum(0, 1));
  EXPECT_EQ(0, Utils::Minimum(1, 0));

  EXPECT_EQ(1, Utils::Minimum(1, 2));
  EXPECT_EQ(1, Utils::Minimum(2, 1));

  EXPECT_EQ(-1, Utils::Minimum(-1, 1));
  EXPECT_EQ(-1, Utils::Minimum(1, -1));

  EXPECT_EQ(-2, Utils::Minimum(-1, -2));
  EXPECT_EQ(-2, Utils::Minimum(-2, -1));
}

TEST_CASE(Maximum) {
  EXPECT_EQ(1, Utils::Maximum(0, 1));
  EXPECT_EQ(1, Utils::Maximum(1, 0));

  EXPECT_EQ(2, Utils::Maximum(1, 2));
  EXPECT_EQ(2, Utils::Maximum(2, 1));

  EXPECT_EQ(1, Utils::Maximum(-1, 1));
  EXPECT_EQ(1, Utils::Maximum(1, -1));

  EXPECT_EQ(-1, Utils::Maximum(-1, -2));
  EXPECT_EQ(-1, Utils::Maximum(-2, -1));
}

TEST_CASE(IsPowerOfTwo) {
  EXPECT(Utils::IsPowerOfTwo(0));
  EXPECT(Utils::IsPowerOfTwo(1));
  EXPECT(Utils::IsPowerOfTwo(2));
  EXPECT(!Utils::IsPowerOfTwo(3));
  EXPECT(Utils::IsPowerOfTwo(4));
  EXPECT(Utils::IsPowerOfTwo(256));

  EXPECT(!Utils::IsPowerOfTwo(-1));
  EXPECT(!Utils::IsPowerOfTwo(-2));
}

TEST_CASE(IsAligned) {
  EXPECT(Utils::IsAligned(0, 0));
  EXPECT(Utils::IsAligned(0, 1));
  EXPECT(Utils::IsAligned(1, 1));

  EXPECT(Utils::IsAligned(0, 2));
  EXPECT(!Utils::IsAligned(1, 2));
  EXPECT(Utils::IsAligned(2, 2));

  EXPECT(Utils::IsAligned(32, 8));
  EXPECT(!Utils::IsAligned(33, 8));
  EXPECT(Utils::IsAligned(40, 8));
}

TEST_CASE(RoundDown) {
  EXPECT_EQ(0, Utils::RoundDown(0, 0));
  EXPECT_EQ(0, Utils::RoundDown(22, 32));
  EXPECT_EQ(32, Utils::RoundDown(33, 32));
  EXPECT_EQ(32, Utils::RoundDown(63, 32));
}

TEST_CASE(RoundUp) {
  EXPECT_EQ(0, Utils::RoundUp(0, 0));
  EXPECT_EQ(32, Utils::RoundUp(22, 32));
  EXPECT_EQ(64, Utils::RoundUp(33, 32));
  EXPECT_EQ(64, Utils::RoundUp(63, 32));
}

}  // namespace fletch
