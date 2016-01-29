// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/vm/object_map.h"
#include "src/shared/test_case.h"

namespace fletch {

TEST_CASE(ObjectMap) {
  ObjectMap map(256);
  for (int i = 0; i < 1024; i++) {
    map.Add(i, Smi::FromWord(i));
  }
  EXPECT_EQ(1024, map.size());

  for (int i = 0; i < 1024; i++) {
    EXPECT_EQ(i, Smi::cast(map.LookupById(i))->value());
    EXPECT_EQ(i, map.LookupByObject(Smi::FromWord(i)));
  }

  for (int i = 0; i < 1024; i++) {
    map.ClearTableByObject();
    EXPECT_EQ(i, map.LookupByObject(Smi::FromWord(i)));
  }

  EXPECT_EQ(100, map.LookupByObject(Smi::FromWord(100)));
  EXPECT(map.RemoveByObject(Smi::FromWord(100)));
  EXPECT_EQ(1023, map.size());
  EXPECT(!map.RemoveByObject(Smi::FromWord(100)));
  EXPECT_EQ(1023, map.size());
  EXPECT_EQ(-1, map.LookupByObject(Smi::FromWord(100)));
  map.Add(100, Smi::FromWord(100));
  EXPECT_EQ(100, map.LookupByObject(Smi::FromWord(100)));
  map.Add(100, Smi::FromWord(101));
  EXPECT_EQ(100, map.LookupByObject(Smi::FromWord(101)));
  EXPECT_EQ(Smi::FromWord(101), map.LookupById(100));
  EXPECT_EQ(1024, map.size());

  for (int i = 0; i < 1024; i++) {
    EXPECT(map.RemoveById(i));
    EXPECT(!map.RemoveById(i));
    EXPECT(map.LookupById(i) == NULL);
    EXPECT_EQ(-1, map.LookupByObject(Smi::FromWord(i)));
  }
  EXPECT_EQ(0, map.size());
}

}  // namespace fletch
