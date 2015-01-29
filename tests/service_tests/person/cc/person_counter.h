// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERSON_COUNTER_H
#define PERSON_COUNTER_H

class Person;
class Segment;

class PersonCounter {
 public:
  static void Setup();
  static void TearDown();

  static int GetAge(Person person);
  // TODO(kasperl): Add async variant.
};

class Person {
 public:
  static const int kSize = 4;

  Person(Segment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  inline int age() const;

  Segment* segment() const { return segment_; }
  int offset() const { return offset_; }

 private:
  Segment* const segment_;
  const int offset_;
};

class PersonBuilder {
 public:
  PersonBuilder(Segment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  inline void set_age(int value);

 private:
  Segment* const segment_;
  const int offset_;
};

class Segment {
 public:
  explicit Segment(int capacity);
  ~Segment();

  void* At(int offset) const { return memory_ + offset; }

  int Allocate(int size);

 private:
  char* const memory_;
  const int capacity_;

  int used_;
};

class MessageBuilder {
 public:
  MessageBuilder();

  Person Root();
  PersonBuilder NewRoot();

 private:
  Segment segment_;
};

int Person::age() const {
  int* pointer = reinterpret_cast<int*>(segment_->At(offset_));
  return *pointer;
}

void PersonBuilder::set_age(int value) {
  int* pointer = reinterpret_cast<int*>(segment_->At(offset_));
  *pointer = value;
}

#endif  // PERSON_COUNTER_H
