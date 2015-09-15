// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
#ifndef SRC_VM_VOID_HASH_TABLE_H_
#define SRC_VM_VOID_HASH_TABLE_H_

#include "src/shared/globals.h"
#include "src/shared/assert.h"

namespace fletch {

class VoidHashTable {
 public:
  explicit VoidHashTable(size_t value_size);
  ~VoidHashTable();

  char* Find(const void* key);

  char* At(const void* key);

  char* Insert(const void* key, const char* pair, bool* inserted);

  char* Erase(const char* entry);

  void Swap(VoidHashTable& other);

  void Clear();

  // Used to implement the [] operator.  Returns address of value part of
  // key-value pair.
  char* LookUp(const void* key);

  size_t size() const { return size_; }

  const char* backing() const { return backing_; }

  char* backing() { return backing_; }

  const char* backing_end() const { return backing_end_; }

  char* backing_end() { return backing_end_; }

#ifdef DEBUG
  size_t mutations() const { return mutations_; }
#endif

  template<typename Pointer>
  class Iterator {
   public:
    inline Iterator(
        const VoidHashTable* table, Pointer position, size_t entry_size)
        : position_(position)
#ifdef DEBUG
        , table_(table)
        , mutations_(table == NULL ? 0 : table->mutations())
#endif
        , entry_size_(entry_size) { }

    template<typename OtherPointer>
    inline Iterator(const Iterator<OtherPointer>& other)
        : position_(other.position_)
#ifdef DEBUG
        , table_(other.table_)
        , mutations_(other.mutations_)
#endif
        , entry_size_(other.entry_size_) { }

    inline void AdvanceToUsedSlot() {
      while (IsUnused(position_)) {
        Increment();
      }
    }

    inline void Increment() {
#ifdef DEBUG
      ASSERT(mutations_ == table_->mutations());
#endif
      position_ += entry_size_;
    }

    Pointer operator*() const {
#ifdef DEBUG
      ASSERT(mutations_ == table_->mutations());
#endif
      // Skip the hash code.
      return position_ + sizeof(hash_t);
    }

    Pointer position() { return position_; }

    template<typename OtherPointer>
    bool operator==(const Iterator<OtherPointer>& other) const {
      return other.position_ == position_;
    }

    template<typename OtherPointer>
    bool operator!=(const Iterator<OtherPointer>& other) const {
      return !(*this == other);
    }

    Pointer position_;
#ifdef DEBUG
    const VoidHashTable* table_;
    size_t mutations_;
#endif
    size_t entry_size_;
  };

  typedef intptr_t hash_t;

 private:
  void Rehash(size_t new_capacity);

  void AllocateBacking(size_t capacity);

  char* FindStopBucket(char* entry);

  size_t capacity() { return mask_ + 1; }

  char* RawFind(const void* key, bool* inserted_return);

  static inline const void** KeyFromEntry(char* entry) {
    return reinterpret_cast<const void**>(entry + sizeof(hash_t));
  }

  static inline void* const* KeyFromEntry(const char* entry) {
    return reinterpret_cast<void* const*>(entry + sizeof(hash_t));
  }

  static inline char* PairFromEntry(char* entry) {
    return entry + sizeof(hash_t);
  }

  static inline const char* PairFromEntry(const char* entry) {
    return entry + sizeof(hash_t);
  }

  static inline char* ValueFromEntry(char* entry) {
    return reinterpret_cast<char*>(entry + sizeof(hash_t) + sizeof(void*));
  }

  size_t SizeOfPair() const { return entry_size_ - sizeof(hash_t); }
  size_t SizeOfValue() const { return SizeOfPair() - sizeof(void*); }

  // Measured in entries.
  static const size_t kInitialCapacity = 4;
  // Raw hash code of unused slot.
  static const hash_t kUnusedSlot = -1;
  // Raw hash code of position after the end.
  static const hash_t kPastTheEnd = 0x446e45;  // EnD.

  static void* GetKey(const char* bucket);

  void SwapEntries(char* p1, char* p2);

  static hash_t HashCode(const void* key);

  static inline hash_t StoredHashCode(const char* entry) {
    return *reinterpret_cast<const hash_t*>(entry);
  }

  static inline void SetHashCode(char* entry, hash_t code) {
    ASSERT(code >= 0);
    *reinterpret_cast<hash_t*>(entry) = code;
  }

  static inline void SetUnused(char* entry) {
    *reinterpret_cast<hash_t*>(entry) = kUnusedSlot;
  }

  static inline bool IsUnused(const char* entry) {
    hash_t raw_code = StoredHashCode(entry);
    return raw_code < 0;
  }

  // We store the entry size on the map, because it leads to slightly lower
  // code size, but actually we could pass it on all methods, since the caller
  // knows it.  The iterator constructors don't look it up here, they just
  // know.
  size_t entry_size_;  // In bytes.
  size_t mask_;        // Capacity (in entries) - 1.
#ifdef DEBUG
  size_t mutations_;
#endif
  size_t size_;        // Entries in use.
  char* backing_;      // The backing store of entries.
  char* backing_end_;  // The end of the backing store of entries.
};

}  // namespace fletch.

#endif  // SRC_VM_VOID_HASH_TABLE_H_
