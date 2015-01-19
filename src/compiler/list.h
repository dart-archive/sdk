// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_LIST_H_
#define SRC_COMPILER_LIST_H_

#include "src/compiler/allocation.h"
#include "src/compiler/zone.h"

namespace fletch {

// Lists are light-weight data structures that hold a sequence of
// contiguous elements. List never take ownership of the data their
// are passed in, so as long as the data is either in a zone or
// static, lists can be safely passed by value.
template<typename T>
class List : public ZoneAllocated {
 public:
  List() : data_(NULL), length_(0) { }

  List(T* data, int length) : data_(data), length_(length) {
    ASSERT(length >= 0);
  }

  T& operator[](int index) {
    ASSERT(index >= 0 && index < length_);
    return data_[index];
  }

  const T& operator[](int index) const {
    ASSERT(index >= 0 && index < length_);
    return data_[index];
  }

  T* data() const { return data_; }
  int length() const { return length_; }
  bool is_empty() const { return length_ == 0; }

  // Allocate a new list in the zone.
  static inline List<T> New(Zone* zone, int length);

  // Allocate a singleton list in the zone.
  static inline List<T> NewSingleton(Zone* zone, T element);

 private:
  T* data_;
  int length_;
};

// Stack lists are used for conveniently allocating and accessing list
// on the C++ stack. Be careful not to let the list returned from ToList()
// outlive the stack list itself.
template<typename T, int length>
class StackList : public StackAllocated {
 public:
  StackList() { }

#ifdef DEBUG
  // In debug mode, the contents is cleared when the buffer is destructed.
  // This is done to help provoke errors earlier.
  ~StackList() {
    memset(contents_, 0, sizeof(T) * kLength);
  }
#endif

  List<T> ToList() { return List<T>(contents_, kLength); }

 private:
  static const int kLength = length;
  T contents_[kLength];

  DISALLOW_COPY_AND_ASSIGN(StackList);
};

template<typename T>
inline List<T> List<T>::New(Zone* zone, int length) {
  T* data = static_cast<T*>(zone->Allocate(sizeof(T) * length));
  return List<T>(data, length);
}

template<typename T>
inline List<T> List<T>::NewSingleton(Zone* zone, T element) {
  T* data = static_cast<T*>(zone->Allocate(sizeof(T)));
  data[0] = element;
  return List<T>(data, 1);
}

}  // namespace fletch

#endif  // SRC_COMPILER_LIST_H_
