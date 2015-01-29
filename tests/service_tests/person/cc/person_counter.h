// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERSON_COUNTER_H
#define PERSON_COUNTER_H

#include <stddef.h>

class PersonBuilder;
class Segment;
class MessageBuilder;
class BuilderSegment;

class PersonCounter {
 public:
  static void Setup();
  static void TearDown();

  // TODO(kasperl): Add async variants.

  // Not quite sure if these methods should take builder or reader
  // views. Somehow the separation isn't very nice yet.
  static int GetAge(PersonBuilder person);
  static int Count(PersonBuilder person);
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
  List(BuilderSegment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  T operator[](int index) {
    // TODO(kasperl): Bounds check?
    return T(segment_, offset_ + (index * T::kSize));
  }

 private:
  BuilderSegment* const segment_;
  const int offset_;
};

class PersonBuilder : public Builder {
 public:
  static const int kSize = Person::kSize;

  PersonBuilder(BuilderSegment* segment, int offset)
      : segment_(segment), offset_(offset) {
  }

  inline void set_age(int value);

  List<PersonBuilder> NewChildren(int length);

  BuilderSegment* segment() const { return segment_; }
  int offset() const { return offset_; }

 private:
  BuilderSegment* const segment_;
  const int offset_;
};

class Segment {
 public:
  Segment(char* memory, int size);

  int size() const { return size_; }

  void* At(int offset) const { return memory_ + offset; }

 protected:
  char* memory() const { return memory_; }

 private:
  char* const memory_;
  const int size_;
};

class BuilderSegment : public Segment {
 public:
  int Allocate(int bytes);

  int id() const { return id_; }
  int used() const { return used_; }
  MessageBuilder* builder() const { return builder_; }

  BuilderSegment* next() const { return next_; }
  bool HasNext() const { return next_ != NULL; }
  bool HasSpaceForBytes(int bytes) const { return used_ + bytes <= size(); }

 private:
  BuilderSegment(MessageBuilder* builder, int id, int capacity);
  ~BuilderSegment();

  MessageBuilder* const builder_;
  const int id_;
  BuilderSegment* next_;
  int used_;

  void set_next(BuilderSegment* segment) { next_ = segment; }

  friend class MessageBuilder;
};

class MessageBuilder {
 public:
  explicit MessageBuilder(int space);

  BuilderSegment* first() { return &first_; }
  int segments() const { return segments_; }

  Person Root();
  PersonBuilder NewRoot();

  int ComputeUsed() const;

  BuilderSegment* FindSegmentForBytes(int bytes);

 private:
  BuilderSegment first_;
  BuilderSegment* last_;
  int segments_;
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
