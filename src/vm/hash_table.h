// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HASH_TABLE_H_
#define SRC_VM_HASH_TABLE_H_

#include "src/shared/assert.h"
#include "src/vm/pair.h"
#include "src/vm/void_hash_table.h"

namespace fletch {

// Used to implement UnorderedMap and UnorderedSet (see hash_map.h and
// hashset.h).  Most methods have a very similar interface to
// std::unordered_set and std::unordered_map.
template <typename K, typename V, typename KeyExtractor>
class UnorderedHashTable {
 public:
  UnorderedHashTable() : map_(sizeof(V)) { ASSERT(sizeof(K) == sizeof(void*)); }

  typedef K KeyType;
  // For map, this is a Pair<Key, Mapped>.  For set, this is just the
  // Key type.
  typedef V ValueType;
  typedef size_t SizeType;

 private:
  static const size_t kEntrySize = sizeof(VoidHashTable::hash_t) + sizeof(V);

  template <typename Pointer, typename Value>
  class CommonIterator {
   public:
    inline CommonIterator() : void_iterator_(NULL, NULL, kEntrySize) {}

    inline CommonIterator& operator++() {
      void_iterator_.Increment();
      void_iterator_.AdvanceToUsedSlot();
      return *this;
    }

    inline Value* operator->() {
      return reinterpret_cast<Value*>(*void_iterator_);
    }

    inline Value& operator*() {
      return *reinterpret_cast<Value*>(*void_iterator_);
    }

    template <typename T, typename U>
    bool operator==(const CommonIterator<T, U>& other) const {
      return void_iterator_ == other.void_iterator_;
    }

    template <typename T, typename U>
    bool operator!=(const CommonIterator<T, U>& other) const {
      return !(*this == other);
    }

   protected:
    VoidHashTable::Iterator<Pointer> void_iterator_;

    template <typename T>
    CommonIterator(const VoidHashTable::Iterator<T>& other)  // NOLINT
        : void_iterator_(other) {}

   private:
    Pointer position() { return void_iterator_.position(); }

    inline CommonIterator(const VoidHashTable& map, Pointer position)
        : void_iterator_(&map, position, kEntrySize) {
      void_iterator_.AdvanceToUsedSlot();
    }

    friend class UnorderedHashTable;
  };

 public:
  class Iterator : public CommonIterator<char*, ValueType> {
   public:
    inline Iterator() : Super() {}

   private:
    typedef CommonIterator<char*, ValueType> Super;
    inline Iterator(const VoidHashTable& map, char* position)
        : Super(map, position) {}

    friend class UnorderedHashTable;
  };

  class ConstIterator : public CommonIterator<const char*, const ValueType> {
   public:
    inline ConstIterator() : Super() {}

    ConstIterator(const Iterator& other)  // NOLINT
        : Super(other.void_iterator_) {}

   private:
    typedef CommonIterator<const char*, const ValueType> Super;

    inline ConstIterator(const VoidHashTable& map, const char* position)
        : Super(map, position) {}

    friend class UnorderedHashTable;
  };

  inline Iterator Find(const K& key) {
    return Iterator(map_, map_.Find(reinterpret_cast<const void*>(key)));
  }

  inline ConstIterator Find(const K& key) const {
    return ConstIterator(map_, map_.Find(reinterpret_cast<const void*>(key)));
  }

  inline Pair<Iterator, bool> Insert(const ValueType& value) {
    const void* key_as_void =
        reinterpret_cast<const void*>(KeyExtractor::GetKey(value));
    const char* pair = reinterpret_cast<const char*>(&value);
    bool inserted = false;
    char* entry = map_.Insert(key_as_void, pair, &inserted);
    return {Iterator(map_, entry), inserted};
  }

  inline size_t size() const { return map_.size(); }

  inline bool Empty() const { return map_.size() == 0; }

  inline Iterator Erase(ConstIterator it) {
    char* entry = map_.Erase(it.position());
    return Iterator(map_, entry);
  }

  void Swap(UnorderedHashTable& other) { map_.Swap(other.map_); }

  inline ConstIterator Begin() const {
    ConstIterator answer(map_, map_.backing());
    return answer;
  }

  inline Iterator Begin() {
    Iterator answer(map_, map_.backing());
    return answer;
  }

  inline ConstIterator End() const {
    return ConstIterator(map_, map_.backing_end());
  }

  inline Iterator End() { return Iterator(map_, map_.backing_end()); }

  inline void Clear() { map_.Clear(); }

 protected:
  VoidHashTable map_;
};

}  // namespace fletch

#endif  // SRC_VM_HASH_TABLE_H_
