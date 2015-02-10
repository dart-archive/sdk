// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERSON_COUNTER_H
#define PERSON_COUNTER_H

#include <inttypes.h>
#include "struct.h"

class AgeStats;
class AgeStatsBuilder;
class Person;
class PersonBuilder;
class PersonBox;
class PersonBoxBuilder;
class Node;
class NodeBuilder;
class Cons;
class ConsBuilder;

class PersonCounter {
 public:
  static void setup();
  static void tearDown();
  static int32_t getAge(PersonBuilder person);
  static int32_t getBoxedAge(PersonBoxBuilder box);
  static AgeStats getAgeStats(PersonBuilder person);
  static AgeStats createAgeStats(int32_t averageAge, int32_t sum);
  static Person createPerson(int32_t children);
  static Node createNode(int32_t depth);
  static int32_t count(PersonBuilder person);
  static int32_t depth(NodeBuilder node);
};

class AgeStats : public Reader {
 public:
  static const int kSize = 8;
  AgeStats(Segment* segment, int offset)
      : Reader(segment, offset) { }

  int32_t getAverageAge() const { return *PointerTo<int32_t>(0); }
  int32_t getSum() const { return *PointerTo<int32_t>(4); }
};

class AgeStatsBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit AgeStatsBuilder(const Builder& builder)
      : Builder(builder) { }
  AgeStatsBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setAverageAge(int32_t value) { *PointerTo<int32_t>(0) = value; }
  void setSum(int32_t value) { *PointerTo<int32_t>(4) = value; }
};

class Person : public Reader {
 public:
  static const int kSize = 16;
  Person(Segment* segment, int offset)
      : Reader(segment, offset) { }

  int32_t getAge() const { return *PointerTo<int32_t>(0); }
  List<Person> getChildren() const { return ReadList<Person>(8); }
};

class PersonBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit PersonBuilder(const Builder& builder)
      : Builder(builder) { }
  PersonBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setAge(int32_t value) { *PointerTo<int32_t>(0) = value; }
  List<PersonBuilder> initChildren(int length);
};

class PersonBox : public Reader {
 public:
  static const int kSize = 8;
  PersonBox(Segment* segment, int offset)
      : Reader(segment, offset) { }

  Person getPerson() const;
};

class PersonBoxBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit PersonBoxBuilder(const Builder& builder)
      : Builder(builder) { }
  PersonBoxBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  PersonBuilder initPerson();
};

class Node : public Reader {
 public:
  static const int kSize = 16;
  Node(Segment* segment, int offset)
      : Reader(segment, offset) { }

  uint16_t getTag() const { return *PointerTo<uint16_t>(0); }
  bool isNum() const { return 1 == getTag(); }
  int32_t getNum() const { return *PointerTo<int32_t>(8); }
  bool isCond() const { return 2 == getTag(); }
  bool getCond() const { return *PointerTo<uint8_t>(8) != 0; }
  bool isCons() const { return 3 == getTag(); }
  Cons getCons() const;
};

class NodeBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit NodeBuilder(const Builder& builder)
      : Builder(builder) { }
  NodeBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setTag(uint16_t value) { *PointerTo<uint16_t>(0) = value; }
  void setNum(int32_t value) { setTag(1); *PointerTo<int32_t>(8) = value; }
  void setCond(bool value) { setTag(2); *PointerTo<uint8_t>(8) = value ? 1 : 0; }
  ConsBuilder initCons();
};

class Cons : public Reader {
 public:
  static const int kSize = 16;
  Cons(Segment* segment, int offset)
      : Reader(segment, offset) { }

  Node getFst() const;
  Node getSnd() const;
};

class ConsBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit ConsBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  NodeBuilder initFst();
  NodeBuilder initSnd();
};

#endif  // PERSON_COUNTER_H
