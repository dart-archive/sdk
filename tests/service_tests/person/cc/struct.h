// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef STRUCT_H_
#define STRUCT_H_

#include "include/service_api.h"

#include <inttypes.h>

class Builder;
class MessageBuilder;
class MessageReader;

class Segment {
 public:
  Segment(MessageReader* reader);
  Segment(char* memory, int size);
  virtual ~Segment();

  void* At(int offset) const { return memory_ + offset; }
  MessageReader* reader() const { return reader_; }

  char* memory() const { return memory_; }
  int size() const { return size_; }

 private:
  MessageReader* reader_;
  char* memory_;
  int size_;
};

class MessageReader {
 public:
  MessageReader(int segments, char* memory);
  ~MessageReader();
  Segment* GetSegment(int id) { return segments_[id]; }

  static Segment* GetRootSegment(char* memory, int size);

 private:
  int segment_count_;
  Segment** segments_;
};

class BuilderSegment : public Segment {
 public:
  virtual ~BuilderSegment();

  int Allocate(int bytes);

  void* At(int offset) const { return memory() + offset; }

  int id() const { return id_; }
  int used() const { return used_; }
  MessageBuilder* builder() const { return builder_; }

  BuilderSegment* next() const { return next_; }
  bool HasNext() const { return next_ != NULL; }
  bool HasSpaceForBytes(int bytes) const { return used_ + bytes <= size(); }

 private:
  BuilderSegment(MessageBuilder* builder, int id, int capacity);

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

class Reader;

template<typename T>
class List {
 public:
  inline List(const Reader& reader, int length);

  List(Segment* segment, int offset, int length)
      : segment_(segment), offset_(offset), length_(length) { }

  int length() const { return length_; }

  T operator[](int index) {
    // TODO(kasperl): Bounds check?
    return T(segment_, offset_ + (index * T::kSize));
  }

 private:
  Segment* segment_;
  int offset_;
  int length_;
};

class Reader {
 public:
  Reader(const Reader& reader)
      : segment_(reader.segment()), offset_(reader.offset()) { }

  Segment* segment() const { return segment_; }
  int offset() const { return offset_; }

  // TODO(ager): Delete should only be possible on root readers.
  void Delete() { delete segment_; }

 protected:
  Reader(Segment* segment, int offset)
      : segment_(segment), offset_(offset) { }

  template<typename T>
  const T* PointerTo(int n) const {
    return reinterpret_cast<T*>(segment()->At(offset() + n));
  }

  template<typename T>
  List<T> ReadList(int offset) const {
    Segment* segment = segment_;
    offset += offset_;
    while (true) {
      char* memory = segment->memory();
      int lo = *reinterpret_cast<int*>(memory + offset + 0);
      int hi = *reinterpret_cast<int*>(memory + offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        // Uninitialized, return empty list.
        return List<T>(NULL, 0, 0);
      } else if (tag == 1) {
        return List<T>(segment, lo >> 2, hi);
      } else {
        segment = segment->reader()->GetSegment(hi);
        offset = lo >> 2;
      }
    }
  }

 private:
  Segment* const segment_;
  const int offset_;

  friend class Builder;
};

class Builder {
 public:
  Builder(const Builder& builder)
      : segment_(builder.segment()), offset_(builder.offset()) { }

  BuilderSegment* segment() const { return segment_; }
  int offset() const { return offset_; }

  int64_t InvokeMethod(ServiceId service, MethodId method);

 protected:
  Builder(Segment* segment, int offset)
      : segment_(static_cast<BuilderSegment*>(segment)), offset_(offset) { }

  template<typename T>
  T* PointerTo(int n) {
    return reinterpret_cast<T*>(segment()->At(offset() + n));
  }

  Builder NewStruct(int offset, int size);
  Reader NewList(int offset, int length, int size);

 private:
  BuilderSegment* const segment_;
  const int offset_;

  friend class MessageBuilder;
};

template<typename T>
List<T>::List(const Reader& reader, int length)
      : segment_(reader.segment()),
        offset_(reader.offset()),
        length_(length) { }


#endif  // STRUCT_H_
