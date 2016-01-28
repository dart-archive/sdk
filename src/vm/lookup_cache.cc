// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/lookup_cache.h"

namespace fletch {

LookupCache::LookupCache()
    : primary_(new Entry[kPrimarySize]), secondary_(new Entry[kSecondarySize]) {
  Clear();
  // These asserts need to hold when running on the target, but they don't need
  // to hold on the host (the build machine, where the interpreter-generating
  // program runs).  We put these asserts here on the assumption that the
  // interpreter-generating program will not instantiate this class.
  static_assert(kClassOffset == offsetof(Entry, clazz), "clazz");
  static_assert(kSelectorOffset == offsetof(Entry, selector), "selector");
  static_assert(kTargetOffset == offsetof(Entry, target), "target");
  static_assert(kCodeOffset == offsetof(Entry, code), "code");
}

LookupCache::~LookupCache() {
  delete[] primary_;
  delete[] secondary_;
}

void LookupCache::Clear() {
  memset(primary_, 0, sizeof(Entry) * kPrimarySize);
  memset(secondary_, 0, sizeof(Entry) * kSecondarySize);
}

}  // namespace fletch
