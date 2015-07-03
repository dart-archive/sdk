// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LIST_H_
#define SRC_VM_LIST_H_

#include <stdlib.h>
#include <string.h>
#include "src/shared/assert.h"

namespace fletch {

// Lists are light-weight data structures that hold a sequence of
// contiguous elements. List never take ownership of the data their
// are passed in, so as long as the data is either in a zone or
// static, lists can be safely passed by value.
template<typename T>
class List {
 public:
  List() : data_(NULL), length_(0) { }

  List(T* data, int length) : data_(data), length_(length) {
    ASSERT(length >= 0);
  }

  template<typename S>
  explicit List(List<S> other)
      : data_(reinterpret_cast<T*>(other.data())), length_(other.length()) {
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

  List<T> Sublist(int position, int length) const {
    ASSERT(position >= 0);
    ASSERT(length >= 0);
    ASSERT(position + length <= length_);
    return List<T>(data_ + position, length);
  }

  static List<T> New(int length) {
    return List(static_cast<T*>(malloc(sizeof(T) * length)), length);
  }

  void Reallocate(int length) {
    data_ = static_cast<T*>(realloc(data_, sizeof(T) * length));
    length_ = length;
  }

  void Delete() {
    free(data_);
    data_ = NULL;
    length_ = 0;
  }

 private:
  T* data_;
  int length_;
};

}  // namespace fletch

#endif  // SRC_VM_LIST_H_
