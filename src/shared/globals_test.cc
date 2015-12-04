// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/test_case.h"

namespace fletch {

TEST_CASE(TypeSizes) {
  EXPECT_EQ(1U, sizeof(uint8));
  EXPECT_EQ(1U, sizeof(int8));

  EXPECT_EQ(2U, sizeof(uint16));
  EXPECT_EQ(2U, sizeof(int16));

  EXPECT_EQ(4U, sizeof(uint32));
  EXPECT_EQ(4U, sizeof(int32));

  EXPECT_EQ(8U, sizeof(uint64));
  EXPECT_EQ(8U, sizeof(int64));
}

TEST_CASE(ArraySize) {
  static int i1[] = {1};
  EXPECT_EQ(1U, ARRAY_SIZE(i1));
  static int i2[] = {1, 2};
  EXPECT_EQ(2U, ARRAY_SIZE(i2));
  static int i3[3] = {
      0,
  };
  EXPECT_EQ(3U, ARRAY_SIZE(i3));

  static char c1[] = {1};
  EXPECT_EQ(1U, ARRAY_SIZE(c1));
  static char c2[] = {1, 2};
  EXPECT_EQ(2U, ARRAY_SIZE(c2));
  static char c3[3] = {
      0,
  };
  EXPECT_EQ(3U, ARRAY_SIZE(c3));
}

}  // namespace fletch
