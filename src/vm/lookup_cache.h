// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_LOOKUP_CACHE_H_
#define SRC_VM_LOOKUP_CACHE_H_

#include "src/shared/globals.h"
#include "src/shared/utils.h"

namespace dartino {

class Class;
class Function;

class LookupCache {
 public:
  static const int kPrimarySize = 4096;
  static const int kSecondarySize = 2111;

  // If you add an offset here, remember to add the corresponding static_assert
  // in lookup_cache.cc.
  static const int kClassOffset = 0;
  static const int kSelectorOffset = kClassOffset + sizeof(word);
  static const int kTargetOffset = kSelectorOffset + sizeof(word);
  static const int kCodeOffset = kTargetOffset + sizeof(word);

  struct Entry {
    Class* clazz;
    word selector;
    Function* target;
    void* code;
  };

  LookupCache();
  ~LookupCache();

  Entry* primary() const { return primary_; }
  Entry* secondary() const { return secondary_; }

  inline void DemotePrimary(Entry* primary);

  void Clear();

  static inline uword ComputePrimaryIndex(Class* clazz, int selector);
  static inline uword ComputeSecondaryIndex(Class* clazz, int selector);

 private:
  Entry* const primary_;
  Entry* const secondary_;
};

inline void LookupCache::DemotePrimary(LookupCache::Entry* primary) {
  Class* clazz = primary->clazz;
  if (clazz == NULL) return;
  uword index = ComputeSecondaryIndex(clazz, primary->selector);
  secondary()[index] = *primary;
}

uword LookupCache::ComputePrimaryIndex(Class* clazz, int selector) {
  ASSERT(Utils::IsPowerOfTwo(kPrimarySize));
  uword hash = reinterpret_cast<uword>(clazz) ^ selector;
  return hash & (kPrimarySize - 1);
}

uword LookupCache::ComputeSecondaryIndex(Class* clazz, int selector) {
  ASSERT(!Utils::IsPowerOfTwo(kSecondarySize));
  uword hash = reinterpret_cast<uword>(clazz) - selector;
  return hash % kSecondarySize;
}

}  // namespace dartino

#endif  // SRC_VM_LOOKUP_CACHE_H_
