// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/lookup_cache.h"

namespace fletch {

LookupCache::LookupCache()
    : primary_(new Entry[kPrimarySize]),
      secondary_(new Entry[kSecondarySize]) {
  Clear();
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
