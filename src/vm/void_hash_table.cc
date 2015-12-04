// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <string.h>

#include "src/vm/void_hash_table.h"

namespace fletch {

VoidHashTable::hash_t VoidHashTable::HashCode(const void* key) {
  return reinterpret_cast<intptr_t>(key) & INTPTR_MAX;
}

VoidHashTable::VoidHashTable(size_t pair_size)
    : entry_size_(sizeof(hash_t) + pair_size),
      mask_(kInitialCapacity - 1)
#ifdef DEBUG
      ,
      mutations_(0)
#endif
      ,
      size_(0) {
  AllocateBacking(kInitialCapacity);
}

VoidHashTable::~VoidHashTable() { delete[] backing_; }

void VoidHashTable::AllocateBacking(size_t capacity) {
  size_t length = entry_size_ * capacity + sizeof(hash_t);
  backing_ = new char[length];
  backing_end_ = backing_ + length - sizeof(hash_t);
  for (char* hashes = backing_; hashes < backing_end_; hashes += entry_size_) {
    *reinterpret_cast<hash_t*>(hashes) = kUnusedSlot;
  }
  // An iterator is incremented by finding the next entry with a valid hash
  // code.  This is a dummy valid hash code that ensures the iterator can
  // advance to the end.
  SetHashCode(backing_end_, kPastTheEnd);
}

void* VoidHashTable::GetKey(const char* bucket) {
  return *KeyFromEntry(bucket);
}

void VoidHashTable::SwapEntries(char* p1, char* p2) {
  for (size_t i = 0; i < entry_size_; i += sizeof(hash_t)) {
    hash_t temp = *reinterpret_cast<hash_t*>(p1 + i);
    *reinterpret_cast<hash_t*>(p1 + i) = *reinterpret_cast<hash_t*>(p2 + i);
    *reinterpret_cast<hash_t*>(p2 + i) = temp;
  }
}

// If inserted is not null, create the entry if it does not exist.  Write
// 'true' to 'inserted' if we created the entry.
char* VoidHashTable::RawFind(const void* key, bool* inserted) {
  // We go with max 88% occupancy.
  if (inserted != NULL) {
    if (size_ + (size_ >> 3) >= mask_) Rehash(capacity() * 2);
#ifdef DEBUG
    mutations_++;
#endif
  }
  // Answer is the slot we will return, but it's also the location of any data
  // we are carrying forward.
  char* answer = NULL;
  intptr_t hash_code = HashCode(key);
  intptr_t ideal_position = hash_code & mask_;
  intptr_t current_position = ideal_position;
  char* bucket = backing_ + entry_size_ * current_position;
  while (true) {
    if (IsUnused(bucket)) {
      if (inserted == NULL) return NULL;
      *inserted = true;
      size_++;
      if (answer == NULL) {
        SetHashCode(bucket, hash_code);
        return bucket;
      }
      memcpy(bucket, answer, entry_size_);
      SetHashCode(answer, hash_code);
      return answer;
    } else if (GetKey(bucket) == key) {
      ASSERT(hash_code == StoredHashCode(bucket));
      // We can't have found an entry that needed bumping if the key was
      // already in the map.
      ASSERT(answer == NULL);
      return bucket;
    }
    intptr_t entry_ideal_position = StoredHashCode(bucket) & mask_;
    intptr_t entry_distance = (current_position - entry_ideal_position) & mask_;
    if (entry_distance < current_position - ideal_position) {
      if (inserted == NULL) return NULL;
      if (answer == NULL) {
        answer = bucket;
      } else {
        // Swap them around, so the current bucket goes to 'answer' (the data
        // we are carrying forward) and the data we were carrying goes here.
        SwapEntries(answer, bucket);
      }
      ideal_position = entry_ideal_position;
    }
    current_position++;
    bucket += entry_size_;
    if (bucket == backing_end_) bucket = backing_;
  }
}

char* VoidHashTable::Find(const void* key) {
  char* existing_entry = RawFind(key, NULL);
  if (existing_entry == NULL) return backing_end_;
  return existing_entry;
}

char* VoidHashTable::At(const void* key) {
  char* entry = RawFind(key, NULL);
  if (entry == NULL) return entry;
  return ValueFromEntry(entry);
}

char* VoidHashTable::LookUp(const void* key) {
  bool inserted = false;
  char* entry = RawFind(key, &inserted);
  if (inserted) {
    *KeyFromEntry(entry) = key;
    memset(ValueFromEntry(entry), 0, SizeOfValue());
  }
  return ValueFromEntry(entry);
}

void VoidHashTable::Rehash(size_t capacity) {
  char* old_backing = backing_;
  char* old_backing_end = backing_end_;
  mask_ = capacity - 1;
  size_ = 0;
  AllocateBacking(capacity);

  for (char* p = old_backing; p < old_backing_end; p += entry_size_) {
    if (!IsUnused(p)) {
      const void* key = GetKey(p);
      bool was_inserted = false;
      char* new_entry = RawFind(key, &was_inserted);
      ASSERT(was_inserted);
      memcpy(new_entry, p, entry_size_);
    }
  }

  delete[] old_backing;
}

char* VoidHashTable::Insert(const void* key, const char* pair, bool* inserted) {
  char* entry = RawFind(key, inserted);
  memcpy(PairFromEntry(entry), pair, SizeOfPair());
  return entry;
}

void VoidHashTable::Swap(VoidHashTable& other) {
  size_t t;
  t = entry_size_;
  entry_size_ = other.entry_size_;
  other.entry_size_ = t;
  t = mask_;
  mask_ = other.mask_;
  other.mask_ = t;
#ifdef DEBUG
  t = mutations_;
  mutations_ = other.mutations_;
  other.mutations_ = t;
#endif
  t = size_;
  size_ = other.size_;
  other.size_ = t;
  char* t2;
  t2 = backing_;
  backing_ = other.backing_;
  other.backing_ = t2;
  t2 = backing_end_;
  backing_end_ = other.backing_end_;
  other.backing_end_ = t2;
}

char* VoidHashTable::FindStopBucket(char* entry) {
  while (true) {
    entry += entry_size_;
    if (entry == backing_end_) entry = backing_;
    if (IsUnused(entry)) return entry;
    size_t ideal_position = StoredHashCode(entry) & mask_;
    if (backing_ + ideal_position * entry_size_ == entry) return entry;
  }
}

char* VoidHashTable::Erase(const char* entry) {
#ifdef DEBUG
  mutations_++;
#endif
  // It's OK to delete using a const pointer from a const_iterator because that
  // only says that the individual entries are const, not that the collection
  // is const (and you can delete const things, because that doesn't mutate
  // them it just causes them to stop existing).
  char* position = const_cast<char*>(entry);
  // We need to move down the later elements to fill the gap left by the
  // deleted element.
  char* dest = position;
  char* stop_bucket = FindStopBucket(position);
  if (dest > stop_bucket) {
    // Wraparound case.
    memmove(dest, dest + entry_size_, backing_end_ - (dest + entry_size_));
    if (stop_bucket > backing_) {
      memcpy(backing_end_ - entry_size_, backing_, entry_size_);
      memmove(backing_, backing_ + entry_size_,
              stop_bucket - (backing_ + entry_size_));
    }
  } else if (stop_bucket != dest) {
    size_t len = (stop_bucket - dest) - entry_size_;
    ASSERT(len < INTPTR_MAX);  // No unsigned wrap around.
    memmove(dest, dest + entry_size_, len);
  }
  // Mark the one before the stop position as unused.
  if (stop_bucket == backing_) {
    SetUnused(backing_end_ - entry_size_);
  } else {
    SetUnused(stop_bucket - entry_size_);
  }

  // Don't rehash here, because the contract is that the iterator can still be
  // used.
  size_--;
  return position;
}

void VoidHashTable::Clear() {
  if (size_ == 0) return;
  delete[] backing_;
#ifdef DEBUG
  mutations_++;
#endif
  mask_ = kInitialCapacity - 1;
  size_ = 0;
  AllocateBacking(kInitialCapacity);
}

}  // namespace fletch.
