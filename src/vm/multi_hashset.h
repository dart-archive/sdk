// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_MULTI_HASHSET_H_
#define SRC_VM_MULTI_HASHSET_H_

#include "src/vm/hash_map.h"

namespace fletch {

// MultiHashSet:
// Interface is kept as close as possible to std::unordered_map, but:
// * Only functions that can be expected to be tiny are inlined.
// * The Key type must be memcpy-able and castable to void* and the same size.
// * The hash code is just a cast to int.
// * Not all methods are implemented.
// * Iterators are invalidated on all inserts, even if the key was already
//   present.
// * Google naming conventions are used (CamelCase classes and methods).
template <typename Key>
class MultiHashSet : public UnorderedHashTable<Key, Pair<Key, int>,
                                               MapKeyExtractor<Key, int>> {
 public:
  // Returns 'true' if we inserted [key] the first time.
  bool Add(const Key& key) {
    int* count_ptr = reinterpret_cast<int*>(
        this->map_.LookUp(reinterpret_cast<const void*>(key)));
    int count = *count_ptr;
    *count_ptr = count + 1;
    return count == 0;
  }

  int Count(const Key& key) {
    auto it = this->Find(key);
    if (it != this->End()) {
      return it->second;
    }
    return 0;
  }

  // Returns 'true' if we removed the last [key].
  bool Remove(const Key& key) {
    auto it = this->Find(key);
    if (it == this->End()) return false;

    if (it->second > 1) {
      it->second -= 1;
      return false;
    }

    this->Erase(it);
    return true;
  }
};

}  // namespace fletch

#endif  // SRC_VM_MULTI_HASHSET_H_
