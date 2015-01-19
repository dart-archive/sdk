// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_TRIE_H_
#define SRC_COMPILER_TRIE_H_

#include "src/compiler/zone.h"

namespace fletch {

template<typename T, int InitSize = 2>
class TrieNode : public ZoneAllocated {
 public:
  explicit TrieNode(int id)
    : children_size_(InitSize),
      children_(builtin_),
      id_(id) {
    memset(builtin_, 0, sizeof(builtin_));
  }

  inline T* LookupChild(int id) {
    int index = 0;
    while (index < children_size_) {
      T* child = children_[index];
      if (child == NULL) break;
      if (child->id_ == id) return child;
      index++;
    }
    return NULL;
  }

  inline T* Child(Zone* zone, int id) {
    int index = 0;
    while (index < children_size_) {
      T* child = children_[index];
      if (child == NULL) break;
      if (child->id_ == id) return child;
      index++;
    }
    return NewChild(zone, index, id);
  }

 private:
  T* builtin_[InitSize];
  int children_size_;
  T** children_;
  int id_;

  T* NewChild(Zone* zone, int index, int id) {
    if (index == children_size_) {
      int new_size = children_size_ * 4;
      T** list = reinterpret_cast<T**>(
          zone->Allocate(sizeof(T*) * new_size));
      // Copy old list into new.
      memmove(list, children_, sizeof(T*) * children_size_);
      // Clear the rest of the new list.
      memset(list + children_size_,
             0,
             sizeof(T*) * (new_size - children_size_));
      children_ = list;
      children_size_ = new_size;
    }
    return children_[index] = new(zone) T(zone, id);
  }
};

}  // namespace fletch

#endif  // SRC_COMPILER_TRIE_H_
