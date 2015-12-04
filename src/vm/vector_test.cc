// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. all rights reserved. use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <string.h>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/shared/test_case.h"

#include "src/vm/vector.h"

namespace fletch {

// Some examples with and without a typedef.  It's a lot easier to understand
// with the typedef than without!
typedef const char* ConstString;

bool StringCompare(const char* const* a, const char* const* b) {
  return strcmp(*a, *b) < 0;
}

bool StringReverseCompare(const ConstString* a, const ConstString* b) {
  return strcmp(*a, *b) > 0;
}

bool StringRefCompare(const ConstString& a, const ConstString& b) {
  return strcmp(a, b) < 0;
}

bool StringReverseRefCompare(const char* const& a, const char* const& b) {
  return strcmp(a, b) > 0;
}

bool StringConstCompare(const ConstString* a, const ConstString* b) {
  return strcmp(*a, *b) < 0;
}

bool StringConstReverseCompare(const char* const* a, const char* const* b) {
  return strcmp(*a, *b) > 0;
}

bool StringConstRefCompare(const char* const& a, const char* const& b) {
  return strcmp(a, b) < 0;
}

bool StringConstReverseRefCompare(const char* const& a, const char* const& b) {
  return strcmp(a, b) > 0;
}

TEST_CASE(VECTOR) {
  typedef Vector<const char*> V;
  V vector1;

  EXPECT_EQ(0u, vector1.size());
  vector1.PushBack("foo");
  EXPECT_EQ(1u, vector1.size());
  EXPECT_EQ("foo", vector1[0]);
  vector1.PushBack("bar");
  EXPECT_EQ(2u, vector1.size());
  EXPECT_EQ("foo", vector1[0]);
  EXPECT_EQ("bar", vector1[1]);
  vector1.Sort(StringCompare);
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("foo", vector1[1]);
  vector1.Sort(StringReverseCompare);
  EXPECT_EQ("foo", vector1[0]);
  EXPECT_EQ("bar", vector1[1]);
  vector1[0] = "baz";
  EXPECT_EQ("baz", vector1[0]);
  EXPECT_EQ("bar", vector1[1]);
  vector1.Sort(StringCompare);
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("baz", vector1[1]);
  vector1.PushBack("fizz");
  EXPECT_EQ(3u, vector1.size());
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("baz", vector1[1]);
  EXPECT_EQ("fizz", vector1[2]);
  vector1.Insert(0, "qux");
  EXPECT_EQ(4u, vector1.size());
  EXPECT_EQ("qux", vector1[0]);
  EXPECT_EQ("bar", vector1[1]);
  EXPECT_EQ("baz", vector1[2]);
  EXPECT_EQ("fizz", vector1[3]);
  vector1.Sort(StringCompare, 0, 2);
  EXPECT_EQ(4u, vector1.size());
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("qux", vector1[1]);
  EXPECT_EQ("baz", vector1[2]);
  EXPECT_EQ("fizz", vector1[3]);
  vector1.Sort(StringReverseCompare, 2, 2);
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("qux", vector1[1]);
  EXPECT_EQ("fizz", vector1[2]);
  EXPECT_EQ("baz", vector1[3]);
  vector1.Sort(StringCompare);
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("baz", vector1[1]);
  EXPECT_EQ("fizz", vector1[2]);
  EXPECT_EQ("qux", vector1[3]);
  for (int i = 0; i < 99; i++) {
    vector1.PushBack("problem");
  }
  EXPECT_EQ(103u, vector1.size());
  EXPECT_EQ("problem", vector1[102]);
  vector1.Sort(StringCompare);
  EXPECT_EQ(103u, vector1.size());
  EXPECT_EQ("bar", vector1[0]);
  EXPECT_EQ("problem", vector1[101]);
  EXPECT_EQ("qux", vector1[102]);
  vector1.At(101) = "norf";
  EXPECT_EQ("norf", vector1[101]);
  EXPECT_EQ("bar", vector1.Front());
  EXPECT_EQ("qux", vector1.Back());
  size_t i = vector1.size() - 1;
  EXPECT_EQ("qux", vector1[i]);
  const char** it = vector1.Data();
  EXPECT_EQ("bar", *it);
  it++;
  EXPECT_EQ("baz", *it);

  V vector2;
  EXPECT_EQ(0u, vector2.size());
  vector2.Swap(vector1);
  EXPECT_EQ(0u, vector1.size());
  EXPECT_EQ(103u, vector2.size());
  EXPECT_EQ("qux", vector2.Back());
  const char* popped = vector2.PopBack();
  EXPECT_EQ("qux", popped);
  EXPECT_EQ("norf", vector2.Back());

  vector2.Remove(1);
  EXPECT_EQ("bar", vector2[0]);
  EXPECT_EQ("fizz", vector2[1]);
  EXPECT_EQ(101u, vector2.size());

  vector2.Sort(StringReverseRefCompare);
  EXPECT_EQ("problem", vector2.Front());
  EXPECT_EQ("bar", vector2.Back());

  vector2.Sort(StringConstCompare);
  EXPECT_EQ("bar", vector2.Front());
  EXPECT_EQ("problem", vector2.Back());

  vector2.Sort(StringConstReverseRefCompare);
  EXPECT_EQ("problem", vector2.Front());
  EXPECT_EQ("bar", vector2.Back());

  vector2.Clear();
  EXPECT_EQ(0u, vector2.size());
  EXPECT(vector2.IsEmpty());
}

static bool IntCompare(const int& a, const int& b) { return a < b; }

TEST_CASE(BASIC_VECTOR_TEST) {
  Vector<int> vector;
  EXPECT_EQ(0u, vector.size());
  for (int i = 0; i < 100; i++) {
    vector.PushBack(i);
    vector.PushBack(200 - i);
  }
  EXPECT_EQ(200u, vector.size());
  for (int i = 0; i < 100; i++) {
    EXPECT_EQ(i, vector[i * 2]);
    EXPECT_EQ(200 - i, vector[i * 2 + 1]);
  }
  vector.Remove(50);
  vector.Remove(150);
  EXPECT_EQ(198u, vector.size());
  for (int i = 0; i < 25; i++) {
    EXPECT_EQ(i, vector[i * 2]);
    EXPECT_EQ(200 - i, vector[i * 2 + 1]);
  }
  for (int i = 75; i < 98; i++) {
    EXPECT_EQ(i + 1, vector[i * 2]);
    EXPECT_EQ(200 - (i + 1), vector[i * 2 + 1]);
  }
  vector.Sort(IntCompare);
  int previous = vector[0];
  for (int i = 1; i < 198; i++) {
    EXPECT(previous < vector[i]);
    previous = vector[i];
  }
}

int flip(int i) {
  return ((i & 1) << 9) | ((i & 2) << 7) | ((i & 4) << 5) | ((i & 8) << 3) |
         ((i & 16) << 1) | ((i & 32) >> 1) | ((i & 64) >> 3) |
         ((i & 128) >> 5) | ((i & 256) >> 7) | ((i & 512) >> 9);
}

bool IntFlipCompare(const int& a, const int& b) { return flip(a) < flip(b); }

bool IntDivCompare(const int& a, const int& b) { return a / 10 < b / 10; }

bool FalseCompare(const int& a, const int& b) { return false; }

bool IntReverseCompare(const int& a, const int& b) { return b < a; }

TEST_CASE(SORT_TEST) {
  for (unsigned size = 0; size < 200u; size += (size > 10u ? 13 : 1)) {
    Vector<int> vector;
    for (unsigned i = 0; i < size; i++) {
      vector.PushBack(i);
    }

    int total = 0;
    for (unsigned i = 0; i < vector.size(); i++) {
      total += vector[i];
    }

    vector.Sort(IntFlipCompare);
    int total2 = 0;
    for (unsigned i = 0; i < vector.size(); i++) {
      total2 += vector[i];
      if (i > 0) EXPECT_LT(flip(vector[i - 1]), flip(vector[i]));
    }

    EXPECT_EQ(total, total2);

    vector.Sort(IntCompare);

    total = 0;
    for (unsigned i = 0; i < vector.size(); i++) {
      total += vector[i];
      if (i > 0) EXPECT_LT(vector[i - 1], vector[i]);
    }

    EXPECT_EQ(total, total2);

    vector.Sort(IntFlipCompare);
    vector.Sort(IntDivCompare);

    total = 0;
    for (unsigned i = 0; i < vector.size(); i++) {
      total += vector[i];
      if (i > 0) EXPECT_LE(vector[i - 1] / 10, vector[i] / 10);
    }
    EXPECT_EQ(total, total2);
  }
}

// Random numbers.
static uint32_t x = 42;
static uint32_t y = 103;
static uint32_t z = 31415926;
static uint32_t w = 8310;

static size_t RandomNumberLessThan(size_t max) {
  max &= 0xffffffffu;

  // Smear the bits.
  max |= max >> 16;
  max |= max >> 8;
  max |= max >> 4;
  max |= max >> 2;
  max |= max >> 1;
  uint32_t mask = max >> 1;

  // Xorshift random number.
  uint32_t t = x ^ (x << 11);
  x = y;
  y = z;
  z = w;
  return (w = w ^ (w >> 19) ^ t ^ (t >> 8)) & mask;
}

TEST_CASE(SORT_SPEED_TEST) {
  for (unsigned size = 0; size < 4000u; size += 1000) {
    Vector<int> vector;
    for (unsigned i = 0; i < size; i++) {
      vector.PushBack(RandomNumberLessThan(i));
    }

    vector.Sort(IntCompare);
    vector.Sort(IntReverseCompare);
    for (unsigned i = 1; i < vector.size(); i++) {
      EXPECT_GE(vector[i - 1], vector[i]);
    }
    vector.Sort(FalseCompare);
  }
}

}  // namespace fletch.
