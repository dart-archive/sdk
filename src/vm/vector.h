// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_VECTOR_H_
#define SRC_VM_VECTOR_H_

#include "src/shared/assert.h"

#include "src/vm/sort.h"

namespace fletch {

extern uint8* DoubleSize(size_t capacity, uint8* backing);

template <typename T>
class Vector {
 public:
  typedef T ValueType;
  typedef T& Reference;
  typedef const T& ConstReference;
  typedef size_t SizeType;

  Vector()
      : backing_(reinterpret_cast<T*>(new uint8[kInitialCapacity * sizeof(T)])),
        size_(0),
        capacity_(kInitialCapacity) {}

  ~Vector() { delete[] backing_; }

  Reference operator[](SizeType index) { return At(index); }

  ConstReference operator[](SizeType index) const { return At(index); }

  Reference At(SizeType index) {
    ASSERT(index < size_);
    return backing_[index];
  }

  ConstReference At(SizeType index) const {
    ASSERT(index < size_);
    return backing_[index];
  }

  Reference Front() { return At(0); }

  ConstReference Front() const { return At(0); }

  Reference Back() { return At(size() - 1); }

  ConstReference Back() const { return At(size() - 1); }

  T* Data() { return backing_; }

  const T* Data() const { return backing_; }

  void Sort(typename SortType<T>::Compare compare) {
    fletch::Sort<T>(backing_, size_, compare);
  }

  void Sort(typename SortType<T>::PointerCompare compare) {
    fletch::Sort<T>(backing_, size_, compare);
  }

  void Sort(typename SortType<T>::Compare compare, size_t start, size_t end) {
    fletch::Sort<T>(backing_ + start, end, compare);
  }

  void Sort(typename SortType<T>::PointerCompare compare, size_t start,
            size_t end) {
    fletch::Sort<T>(backing_ + start, end, compare);
  }

  void Swap(Vector& other) {
    T* t = backing_;
    backing_ = other.backing_;
    other.backing_ = t;
    SizeType t2 = size_;
    size_ = other.size_;
    other.size_ = t2;
    t2 = capacity_;
    capacity_ = other.capacity_;
    other.capacity_ = t2;
  }

  void Clear() {
#ifdef DEBUG
    memset(reinterpret_cast<uint8*>(backing_), 0xdd, size_ * sizeof(T));
#endif
    size_ = 0;
  }

  void PushBack(T t) {
    if (size_ == capacity_) {
      Grow();
    }
    size_++;
    At(size_ - 1) = t;
  }

  T PopBack() {
    ASSERT(!IsEmpty());
    T t = At(size_ - 1);
    size_--;
#ifdef DEBUG
    uint8* base = reinterpret_cast<uint8*>(backing_ + size_);
    memset(base, 0xbb, sizeof(T));
#endif
    return t;
  }

  void Insert(SizeType index, T t) {
    ASSERT(index < size_);
    if (size_ == capacity_) {
      Grow();
    }
    uint8* end = reinterpret_cast<uint8*>(backing_ + size_);
    uint8* position = reinterpret_cast<uint8*>(backing_ + index);
    ASSERT(position < end);
    memmove(position + sizeof(T), position, end - position);
    *reinterpret_cast<T*>(position) = t;
    size_++;
  }

  void Remove(SizeType index) {
    ASSERT(index < size_);
    T* victim = backing_ + index;
    T* end = backing_ + size_;
    ASSERT(victim < end);
    uint8* addr = reinterpret_cast<uint8*>(victim);
    uint8* end_addr = reinterpret_cast<uint8*>(end);
    memmove(addr, addr + sizeof(T), end_addr - addr - sizeof(T));
    size_--;
  }

  SizeType size() const { return size_; }

  bool IsEmpty() const { return size_ == 0; }

 private:
  static const SizeType kInitialCapacity = 4;

  void Grow() {
    backing_ = reinterpret_cast<T*>(
        DoubleSize(capacity_ * sizeof(T), reinterpret_cast<uint8*>(backing_)));
    capacity_ *= 2;
  }

  T* backing_;
  size_t size_;
  size_t capacity_;
};

}  // namespace fletch

#endif  // SRC_VM_VECTOR_H_
