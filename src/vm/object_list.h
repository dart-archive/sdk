// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_OBJECT_LIST_H_
#define SRC_VM_OBJECT_LIST_H_

#include "src/shared/globals.h"

#include "src/vm/object.h"
#include "src/vm/list.h"

namespace fletch {

class ObjectList {
 public:
  explicit ObjectList(int capacity);
  virtual ~ObjectList();

  int length() const { return length_; }
  bool is_empty() const { return length_ == 0; }

  Object* operator[](int index) const {
    ASSERT(index >= 0 && index < length_);
    return contents_[index];
  }

  void Add(Object* object);
  Object* Last() const { return contents_[length_ - 1]; }
  Object* RemoveLast() { return contents_[--length_]; }

  void DropLast(int count) {
    ASSERT(length_ >= count);
    length_ -= count;
  }

  void Clear();

  void IteratePointers(PointerVisitor* visitor);

 private:
  List<Object*> contents_;
  int length_;
};

}  // namespace fletch

#endif  // SRC_VM_OBJECT_LIST_H_
