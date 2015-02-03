// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef STRUCT_H_
#define STRUCT_H_

#include "include/service_api.h"

class Builder;
class MessageBuilder;

class Segment {
 public:
  Segment(char* memory, int size);

  void* At(int offset) const { return memory_ + offset; }

 protected:
  char* memory() const { return memory_; }
  int size() const { return size_; }

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

  template<typename T>
  T NewRoot() { return T(InternalNewRoot(T::kSize)); }

  int ComputeUsed() const;

  BuilderSegment* FindSegmentForBytes(int bytes);

 private:
  BuilderSegment first_;
  BuilderSegment* last_;
  int segments_;

  Builder InternalNewRoot(int size);
};

class Reader {
 public:
  Segment* segment() const { return segment_; }
  int offset() const { return offset_; }

 protected:
  Reader(Segment* segment, int offset)
      : segment_(segment), offset_(offset) { }

  template<typename T>
  const T* PointerTo(int n) const {
    return reinterpret_cast<T*>(segment()->At(offset() + n));
  }

 private:
  Segment* const segment_;
  const int offset_;
};

class Builder {
 public:
  Builder(const Builder& builder)
      : segment_(builder.segment()), offset_(builder.offset()) { }

  BuilderSegment* segment() const { return segment_; }
  int offset() const { return offset_; }

  int InvokeMethod(ServiceId service, MethodId method);

 protected:
  Builder(BuilderSegment* segment, int offset)
      : segment_(segment), offset_(offset) { }

  template<typename T>
  T* PointerTo(int n) {
    return reinterpret_cast<T*>(segment()->At(offset() + n));
  }

  Builder NewList(int offset, int length, int size);

 private:
  BuilderSegment* const segment_;
  const int offset_;

  friend class MessageBuilder;
};

template<typename T>
class List : public Builder {
 public:
  explicit List(const Builder& builder)
      : Builder(builder) { }

  List(BuilderSegment* segment, int offset)
      : Builder(segment, offset) { }

  T operator[](int index) {
    // TODO(kasperl): Bounds check?
    return T(segment(), offset() + (index * T::kSize));
  }
};

#endif  // STRUCT_H_
