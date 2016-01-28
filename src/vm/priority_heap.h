// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_PRIORITY_HEAP_H_
#define SRC_VM_PRIORITY_HEAP_H_

#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/vm/hash_map.h"

namespace fletch {

template <typename P, typename V>
class PriorityHeapWithValueIndex {
 public:
  static const int kMinimumSize = 16;

  typedef struct {
    P priority;
    V value;
  } Entry;

  PriorityHeapWithValueIndex() {
    backing_size_ = kMinimumSize;
    backing_ = reinterpret_cast<Entry*>(malloc(sizeof(Entry) * backing_size_));
    if (backing_ == NULL) FATAL("Cannot allocate memory.");
    size_ = 0;
  }

  ~PriorityHeapWithValueIndex() { free(backing_); }

  bool IsEmpty() { return size_ == 0; }

  void Insert(const P& priority, const V& value) {
    ASSERT(!ContainsValue(value));

    if (size_ == backing_size_) {
      Resize(backing_size_ << 1);
    }

    Set(size_, {priority, value});
    BubbleUp(size_);

    size_++;
  }

  const Entry& Minimum() {
    ASSERT(!IsEmpty());
    return backing_[0];
  }

  void RemoveMinimum() {
    ASSERT(!IsEmpty());
    RemoveAt(0);
  }

  bool RemoveByValue(const V& value) {
    auto it = hashmap_.Find(value);
    if (it != hashmap_.End()) {
      int offset = it->second;
      RemoveAt(offset);

      ASSERT(hashmap_.size() == static_cast<uword>(size_));
      return true;
    }
    return false;
  }

  bool ContainsValue(const V& value) {
    return hashmap_.Find(value) != hashmap_.End();
  }

  bool InsertOrChangePriority(const P& priority, const V& value) {
    auto it = hashmap_.Find(value);
    if (it == hashmap_.End()) {
      Insert(priority, value);
      return true;
    }

    int offset = it->second;
    ASSERT(offset < size_);

    Entry& entry = backing_[offset];
    entry.priority = priority;
    if (offset == 0) {
      BubbleDown(offset);
    } else {
      int parent = (offset - 1) / 2;
      int diff = entry.priority - backing_[parent].priority;
      if (diff < 0) {
        BubbleUp(offset);
      } else if (diff > 0) {
        BubbleDown(offset);
      }
    }
    return false;
  }

#ifdef TESTING
  int backing_size() { return backing_size_; }
#endif  // TESTING

 private:
  void RemoveAt(int offset) {
    ASSERT(offset < size_);

    size_--;

    if (offset == size_) {
      auto it = hashmap_.Find(backing_[offset].value);
      ASSERT(it != hashmap_.End());
      hashmap_.Erase(it);
    } else {
      Replace(offset, size_);
      BubbleDown(offset);
    }

    if (size_ <= (backing_size_ >> 2) && kMinimumSize <= (backing_size_ >> 1)) {
      Resize(backing_size_ >> 1);
    }
  }

  void BubbleUp(int offset) {
    while (true) {
      if (offset == 0) return;

      int parent = (offset - 1) / 2;
      if (backing_[parent].priority > backing_[offset].priority) {
        Swap(parent, offset);
      }
      offset = parent;
    }
  }

  void BubbleDown(int offset) {
    while (true) {
      int left_child_index = 2 * offset + 1;
      bool has_left_child = left_child_index < size_;

      if (!has_left_child) return;

      int smallest_index = offset;

      if (backing_[left_child_index].priority < backing_[offset].priority) {
        smallest_index = left_child_index;
      }

      int right_child_index = left_child_index + 1;
      bool has_right_child = right_child_index < size_;
      if (has_right_child) {
        if (backing_[right_child_index].priority <
            backing_[smallest_index].priority) {
          smallest_index = right_child_index;
        }
      }

      if (offset == smallest_index) {
        return;
      }

      Swap(offset, smallest_index);
      offset = smallest_index;
    }
  }

  void Set(int offset1, const Entry& entry) {
    backing_[offset1] = entry;
    hashmap_[entry.value] = offset1;
  }

  void Swap(int offset1, int offset2) {
    Entry temp = backing_[offset1];
    backing_[offset1] = backing_[offset2];
    backing_[offset2] = temp;

    hashmap_[backing_[offset1].value] = offset1;
    hashmap_[backing_[offset2].value] = offset2;
  }

  void Replace(int index, int withOther) {
    auto it = hashmap_.Find(backing_[index].value);
    ASSERT(it != hashmap_.End());
    hashmap_.Erase(it);

    const Entry& entry = backing_[withOther];
    hashmap_[entry.value] = index;
    backing_[index] = entry;
  }

  void Resize(int new_backing_size) {
    ASSERT(size_ < new_backing_size);
    ASSERT(new_backing_size != backing_size_)

    Entry* new_backing = reinterpret_cast<Entry*>(
        realloc(backing_, sizeof(Entry) * new_backing_size));
    if (new_backing == NULL) FATAL("Cannot allocate memory.");

    backing_ = new_backing;
    backing_size_ = new_backing_size;
  }

  Entry* backing_;
  int backing_size_;
  int size_;
  HashMap<V, int> hashmap_;
};

}  // namespace fletch

#endif  // SRC_VM_PRIORITY_HEAP_H_
