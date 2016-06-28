// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_DOUBLE_LIST_H_
#define SRC_VM_DOUBLE_LIST_H_

#include "src/shared/globals.h"
#include "src/shared/assert.h"

namespace dartino {

template <typename T, int N>
class DoubleList;

template <typename T, int N = 1>
class DoubleListEntry {
 public:
  DoubleListEntry() : next_(NULL), prev_(NULL) {}

  ~DoubleListEntry() {
    // Either this is an unlinked entry or a head/anchor.
    ASSERT((next_ == NULL && prev_ == NULL) ||
           (next_ == this && prev_ == this));
  }

 private:
  void MakeHead() {
    ASSERT(next_ == NULL && prev_ == NULL);
    next_ = prev_ = this;
  }

  // This uses the C++ compiler's ability to convert between classes inside a
  // (possibly multi-) inheritance hierarchy.
  //
  // The non-typesafe C equivalent of this is:
  //
  //     ((uint8*)this) - offsetof(ContainerType, list_entry);
  //
  T* container() { return static_cast<T*>(this); }

  void Append(DoubleListEntry* entry) {
    ASSERT(entry->next_ == NULL && entry->prev_ == NULL);
    entry->next_ = next_;
    entry->prev_ = this;
    next_ = entry;
    entry->next_->prev_ = entry;
  }

  void Prepend(DoubleListEntry* entry) {
    ASSERT(entry->next_ == NULL && entry->prev_ == NULL);
    entry->next_ = this;
    entry->prev_ = prev_;
    prev_ = entry;
    entry->prev_->next_ = entry;
  }

  void Remove() {
    ASSERT(prev_->next_ == this);
    ASSERT(next_->prev_ == this);
    ASSERT(prev_ != this && next_ != this);

    prev_->next_ = next_;
    next_->prev_ = prev_;

    next_ = NULL;
    prev_ = NULL;
  }

  bool IsEmpty() const {
    bool result = next_ == this;
    ASSERT(result == (prev_ == this));
    return result;
  }

  bool IsLinked() {
    ASSERT((next_ == NULL) == (prev_ == NULL));
    return next_ != NULL;
  }

  DoubleListEntry* Prev() { return prev_; }

  DoubleListEntry* Next() { return next_; }

  friend class DoubleList<T, N>;

  DoubleListEntry* next_;
  DoubleListEntry* prev_;

  DISALLOW_COPY_AND_ASSIGN(DoubleListEntry);
};

template <typename T, int N = 1>
class DoubleList {
 public:
  typedef DoubleListEntry<T, N> Entry;

  template <typename ContainerType, int I = 1>
  class Iterator {
   public:
    Iterator(DoubleList<ContainerType, I>* head,
             DoubleListEntry<ContainerType, I>* entry)
        : head_(head), entry_(entry) {}

    inline ContainerType* operator->() {
      return entry_->container();
    }

    inline ContainerType* operator*() {
      return entry_->container();
    }

    inline bool operator==(const Iterator<ContainerType, I>& other) const {
      return entry_ == other.entry_;
    }

    inline bool operator!=(const Iterator<ContainerType, I>& other) const {
      return !(*this == other);
    }

    inline Iterator<ContainerType, I>& operator++() {
      entry_ = entry_->Next();
      return *this;
    }

    inline Iterator<ContainerType, I>& operator--() {
      entry_ = entry_->Prev();
      return *this;
    }

   private:
    friend DoubleList;

    DoubleList<ContainerType, I>* head_;
    DoubleListEntry<ContainerType, I>* entry_;
  };

  inline DoubleList() {
    head_.MakeHead();
  }

  inline void Append(T* a) {
    head_.Prepend(convert(a));
  }

  inline void Prepend(T* a) {
    head_.Append(convert(a));
  }

  // NOTE: This function only checks whether [a] is linked inside *a*
  // [DoubleList].
  inline bool IsInList(T* a) {
    return convert(a)->IsLinked();
  }

  inline void Remove(T* a) {
    convert(a)->Remove();
  }

  inline bool IsEmpty() const { return head_.IsEmpty(); }

  inline T* First() {
    ASSERT(!IsEmpty());
    return head_.Next()->container();
  }

  inline T* Last() {
    ASSERT(!IsEmpty());
    return head_.Prev()->container();
  }

  inline T* RemoveFirst() {
    ASSERT(!IsEmpty());
    auto entry = head_.Next();
    T* container = entry->container();
    entry->Remove();
    return container;
  }

  inline T* RemoveLast() {
    ASSERT(!IsEmpty());
    auto entry = head_.Prev();
    T* container = entry->container();
    entry->Remove();
    return container;
  }

  inline Iterator<T, N> Begin() { return Iterator<T, N>(this, head_.Next()); }

  inline Iterator<T, N> End() { return Iterator<T, N>(this, &head_); }

  inline Iterator<T, N> begin() { return Begin(); }

  inline Iterator<T, N> end() { return End(); }

  inline Iterator<T, N> Erase(const Iterator<T, N>& iterator) {
    ASSERT(iterator.head_ == this);
    Iterator<T, N> next(this, iterator.entry_->Next());
    iterator.entry_->Remove();
    return next;
  }

  inline Iterator<T, N> Insert(const Iterator<T, N>& iterator, T* element) {
    iterator.entry_->Prepend(convert(element));
    return Iterator<T, N>(this, element);
  }

#ifdef DEBUG
  void Dump() {
    for (auto t : this) {
      fprintf(stderr, "%p\n", &t);
    }
  }
#endif

 private:
  Entry head_;

  Entry* convert(T* entry) {
    return static_cast<Entry*>(entry);
  }
};

}  // namespace dartino.

#endif  // SRC_VM_DOUBLE_LIST_H_
