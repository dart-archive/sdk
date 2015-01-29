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

  // TODO(kasperl): Add async variants.
  static int GetAge(Person person);
  static int Count(Person person);
};

class Person {
 public:
  static const int kAgeOffset = 0;
  static const int kChildrenOffset = 8;
  static const int kSize = 16;

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

class Builder {
  // TODO(kasperl): Put the segment and offset up here.
};

template<typename T>
class List : public Builder {
 public:
  List(Segment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  T operator[](int index) {
    // TODO(kasperl): Bounds check?
    return T(segment_, offset_ + (index * T::kSize));
  }

 private:
  Segment* const segment_;
  const int offset_;
};

class PersonBuilder : public Builder {
 public:
  static const int kSize = Person::kSize;

  PersonBuilder(Segment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  inline void set_age(int value);

  List<PersonBuilder> NewChildren(int length);

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
  int used() const { return used_; }

 private:
  char* const memory_;
  const int capacity_;

  int used_;
};

class MessageBuilder {
 public:
  explicit MessageBuilder(int space);

  Person Root();
  PersonBuilder NewRoot();

  Segment* segment() { return &segment_; }

 private:
  Segment segment_;
};

int Person::age() const {
  int offset = offset_ + Person::kAgeOffset;
  int* pointer = reinterpret_cast<int*>(segment_->At(offset));
  return *pointer;
}

void PersonBuilder::set_age(int value) {
  int offset = offset_ + Person::kAgeOffset;
  int* pointer = reinterpret_cast<int*>(segment_->At(offset));
  *pointer = value;
}

#endif  // PERSON_COUNTER_H
