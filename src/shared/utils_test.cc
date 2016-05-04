// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/shared/test_case.h"
#include "src/shared/utils.h"
#include "src/shared/version.h"

namespace dartino {

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

TEST_CASE(Version) {
  const char* edge1 = "0.4.0-edge.850eb8cee22b52d1249948530fdae1ecf602aa40";
  const char* edge2 = "0.4.0-edge.ab960263bee04113f63c604ae04bf68fd0b0446c";
  const char* edge3 = "0.4.1-edge.ab960263bee04113f63c604ae04bf68fd0b0446c";
  const char* dev1 = "0.4.0-dev.0.0";
  const char* dev2 = "0.4.0-dev.1.2";
  const char* dev3 = "0.4.1-dev.1.2";
  const char* stable1 = "0.4.0";
  const char* stable2 = "0.4.1";

  // All 0.4.0 versions.
  const char* set1[] = { edge1, edge2, dev1, dev2, stable1 };
  const int kSet1Length = 5;
  // All 0.4.1 versions.
  const char* set2[] = { edge3, dev3, stable2 };
  const int kSet2Length = 3;

  for (int i = 0; i < kSet1Length; i++) {
    for (int j = 0; j < kSet1Length; j++) {
      if (i == j) {
        EXPECT(Version::Check(set1[i], strlen(set1[i]),
                              set1[j], strlen(set1[j])));
        EXPECT(Version::Check(set1[i], strlen(set1[i]),
                              set1[j], strlen(set1[j]), Version::kExact));
      } else {
        EXPECT(!Version::Check(set1[i], strlen(set1[i]),
                               set1[j], strlen(set1[j])));
        EXPECT(!Version::Check(set1[i], strlen(set1[i]),
                               set1[j], strlen(set1[j]), Version::kExact));
        EXPECT(Version::Check(set1[i], strlen(set1[i]),
                              set1[j], strlen(set1[j]), Version::kCompatible));
      }
    }
    for (int j = 0; j < kSet2Length; j++) {
      EXPECT(!Version::Check(set1[i], strlen(set1[i]),
                             set2[j], strlen(set2[j])));
      EXPECT(!Version::Check(set1[i], strlen(set1[i]),
                             set2[j], strlen(set2[j]), Version::kExact));
      EXPECT(!Version::Check(set1[i], strlen(set1[i]),
                             set2[j], strlen(set2[j]), Version::kCompatible));
    }
  }
  EXPECT(!Version::Check("0.4.1", 5, "0.4.10", 6, Version::kCompatible));
}

}  // namespace dartino
