// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/test_case.h"

TEST_CASE(Assert) {
  ASSERT(true);
  ASSERT(87 == 87);
  ASSERT(42 != 87);

  ASSERT_EQ(0, 0);
  ASSERT_EQ(42, 42);
  ASSERT_EQ(true, true);
  void* pointer = reinterpret_cast<void*>(42);
  ASSERT_EQ(pointer, pointer);

  ASSERT_STREQ("Hello", "Hello");
  ASSERT_STREQ(42, 42);
  ASSERT_STREQ(87, "87");
}

TEST_CASE(Expect) {
  EXPECT(true);
  EXPECT(87 == 87);
  EXPECT(42 != 87);

  EXPECT_EQ(0, 0);
  EXPECT_EQ(42, 42);
  EXPECT_EQ(true, true);
  void* pointer = reinterpret_cast<void*>(42);
  EXPECT_EQ(pointer, pointer);

  EXPECT_STREQ("Hello", "Hello");
  EXPECT_STREQ(42, 42);
  EXPECT_STREQ(87, "87");

  EXPECT_LT(1, 2);
  EXPECT_LT(1, 1.5);
  EXPECT_LT(-1.8, 3.14);

  EXPECT_LE(1, 1);
  EXPECT_LE(1, 2);
  EXPECT_LE(0.5, 1);

  EXPECT_GT(4, 1);
  EXPECT_GT(2.3, 2.2229);

  EXPECT_GE(4, 4);
  EXPECT_GE(15.3, 15.3);
  EXPECT_GE(5, 3);
}
