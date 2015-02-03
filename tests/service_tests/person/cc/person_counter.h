// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERSON_COUNTER_H
#define PERSON_COUNTER_H

#include "struct.h"

class Person : public Reader {
 public:
  static const int kAgeOffset = 0;
  static const int kChildrenOffset = 8;
  static const int kSize = 16;

  Person(Segment* segment, int offset) : Reader(segment, offset) { }

  int age() const { return *PointerTo<int>(kAgeOffset); }
};

class PersonBuilder : public Builder {
 public:
  static const int kSize = Person::kSize;

  explicit PersonBuilder(const Builder& builder)
      : Builder(builder) { }
  PersonBuilder(BuilderSegment* segment, int offset)
      : Builder(segment, offset) { }

  void set_age(int value) { *PointerTo<int>(Person::kAgeOffset) = value; }

  List<PersonBuilder> NewChildren(int length);
};

class AgeStats : public Reader {
 public:
  static const int kAverageAgeOffset = 0;
  static const int kSumOffset = 8;
  static const int kSize = 16;

  AgeStats(Segment* segment, int offset) : Reader(segment, offset) { }

  int averageAge() const { return *PointerTo<int>(kAverageAgeOffset); }
  int sum() const { return *PointerTo<int>(kSumOffset); }
};

class AgeStatsBuilder : public Builder {
 public:
  static const int kSize = AgeStats::kSize;

  explicit AgeStatsBuilder(const Builder& builder)
      : Builder(builder) { }
  AgeStatsBuilder(BuilderSegment* segment, int offset)
      : Builder(segment, offset) { }

  void set_average_age(int value) {
    *PointerTo<int>(AgeStats::kAverageAgeOffset) = value;
  }

  void set_median_age(int value) {
    *PointerTo<int>(AgeStats::kAverageAgeOffset) = value;
  }
};

class PersonCounter {
 public:
  static void Setup();
  static void TearDown();

  // TODO(kasperl): Add async variants.

  // Not quite sure if these methods should take builder or reader
  // views. Somehow the separation isn't very nice yet.
  static int GetAge(PersonBuilder person);
  static AgeStats GetAgeStats(PersonBuilder person);
  static int Count(PersonBuilder person);
};

#endif  // PERSON_COUNTER_H
