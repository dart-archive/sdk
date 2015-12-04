// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_HASH_MAP_H_
#define SRC_VM_HASH_MAP_H_

#include "src/vm/hash_table.h"

namespace fletch {

template <typename Key, typename Mapped>
struct MapKeyExtractor {
  static Key& GetKey(Pair<Key, Mapped>& pair) {  // NOLINT
    return pair.first;
  }

  static const Key& GetKey(const Pair<Key, Mapped>& pair) { return pair.first; }
};

// HashMap:
// Interface is kept as close as possible to std::unordered_map, but:
// * Only functions that can be expected to be tiny are inlined.
// * The Key type must be memcpy-able and castable to void* and the same size.
// * The hash code is just a cast to int.
// * The Value type must be memcpy-able.
// * Not all methods are implemented.
// * Iterators are invalidated on all inserts, even if the key was already
//   present.
// * Google naming conventions are used (CamelCase classes and methods).
template <typename Key, typename Mapped>
class HashMap : public UnorderedHashTable<Key, Pair<Key, Mapped>,
                                          MapKeyExtractor<Key, Mapped>> {
 public:
  // This is perhaps what you would think of as the value type, but that name
  // is used for the key-value pair.
  typedef Mapped MappedType;

  MappedType& operator[](const Key& key) {
    char* mapped = this->map_.LookUp(reinterpret_cast<const void*>(key));
    return *reinterpret_cast<MappedType*>(mapped);
  }

  MappedType& At(const Key& key) {
    char* mapped = this->map_.At(reinterpret_cast<const void*>(key));
    // The original API throws an exception, but we don't use exceptions.
    ASSERT(mapped != NULL);
    return *reinterpret_cast<MappedType*>(mapped);
  }
};

}  // namespace fletch

#endif  // SRC_VM_HASH_MAP_H_
