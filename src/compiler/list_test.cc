// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/list.h"
#include "src/compiler/list_builder.h"
#include "src/shared/test_case.h"
#include "src/compiler/zone.h"

namespace fletch {

TEST_CASE(Empty) {
  Zone zone;
  ListBuilder<int, 8> builder(&zone);
  EXPECT_EQ(0, builder.ToList().length());
  EXPECT(builder.ToList().is_empty());
}

TEST_CASE(LinkedList) {
  Zone zone;
  // Construct a linked list of the first 100 numbers.
  ListBuilder<int, 1> builder(&zone);
  for (int i = 0; i < 100; i++) builder.Add(i);
  List<int> numbers = builder.ToList();
  // Verify that the list has the right elements.
  EXPECT_EQ(100, numbers.length());
  for (int i = 0; i < 100; i++) {
    EXPECT_EQ(i, numbers[i]);
  }
}

TEST_CASE(Chunked) {
  Zone zone;
  // Construct a chunked list of the first 100 numbers.
  ListBuilder<int, 32> builder(&zone);
  for (int i = 0; i < 100; i++) {
    builder.Add(i);
    EXPECT_EQ(i, builder.last());
  }
  List<int> numbers = builder.ToList();
  // Verify that the list has the right elements.
  EXPECT_EQ(100, numbers.length());
  for (int i = 0; i < 100; i++) {
    EXPECT_EQ(i, numbers[i]);
  }
}

TEST_CASE(ByteList) {
  Zone zone;
  ListBuilder<int8, 2> builder(&zone);
  builder.Add(1);
  builder.Add(2);
  builder.Add(3);
  EXPECT_EQ(3, builder.ToList().length());
  EXPECT_EQ(1, builder.ToList()[0]);
  EXPECT_EQ(2, builder.ToList()[1]);
  EXPECT_EQ(3, builder.ToList()[2]);
}

TEST_CASE(IndexedAccess) {
  static const int kElements = 100;
  Zone zone;
  ListBuilder<int, 4> builder(&zone);
  for (int i = 0; i < kElements; i++) {
    builder.Add(i);
    EXPECT_EQ(i, builder.Get(i));
  }
  for (int i = 0; i < kElements; i++) {
    EXPECT_EQ(i, builder.Get(i));
    builder.Set(i, -i);
    EXPECT_EQ(-i, builder.Get(i));
  }
  List<int> numbers = builder.ToList();
  for (int i = 0; i < kElements; i++) {
    EXPECT_EQ(-i, numbers[i]);
  }
}

TEST_CASE(StackList) {
  StackList<int, 8> buffer;
  List<int> list = buffer.ToList();
  for (int i = 0; i < 8; i++) {
    list[i] = i;
  }
  for (int i = 0; i < 8; i++) {
    EXPECT_EQ(i, list[i]);
    EXPECT_EQ(i, buffer.ToList()[i]);
  }
}

TEST_CASE(RemoveLast) {
  Zone zone;
  for (int i = 1; i < 32; i++) {
    ListBuilder<int, 8> builder(&zone);
    for (int j = 0; j < i; j++) {
      builder.Add(j);
    }
    for (int j = i - 1; j >= 0; j--) {
      EXPECT_EQ(j, builder.RemoveLast());
      List<int> numbers = builder.ToList();
      // Verify that the list has the right elements.
      EXPECT_EQ(j, numbers.length());
      for (int k = 0; k < j; k++) {
        EXPECT_EQ(k, numbers[k]);
      }
      // See if we can add and remove it again.
      builder.Add(j);
      EXPECT_EQ(j, builder.RemoveLast());
    }
  }
}

TEST_CASE(Clear) {
  Zone zone;
  ListBuilder<int, 8> builder(&zone);
  for (int i = 0; i < 100; i++) builder.Add(i);
  EXPECT_EQ(100, builder.length());
  builder.Clear();
  EXPECT_EQ(0, builder.length());
  for (int i = 0; i < 100; i++) builder.Add(i);
  List<int> numbers = builder.ToList();
  EXPECT_EQ(100, numbers.length());
  for (int i = 0; i < 100; i++) {
    EXPECT_EQ(i, numbers[i]);
  }
}

}  // namespace fletch

