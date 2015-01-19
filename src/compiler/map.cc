// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/map.h"

namespace fletch {

int MapStringHash(const char* value) {
  int length = strlen(value);
  int hash = 0;
  for (int i = 0; i < length; i++) {
    hash = hash << 7 ^ (hash ^ value[i]);
  }
  return hash;
}

bool MapStringCompare(const char* a, const char* b) {
  if (a == b) return true;
  int i = 0;
  while (true) {
    if (a[i] != b[i]) return false;
    if (a[i] == 0) return true;  // We know a[i] == b[i].
    i++;
  }
  UNREACHABLE();
  return false;
}

int MapIntegerHash(const int64 value) {
  int v = value;
  return v >= 0 ? v: -v;
}

bool MapIntegerCompare(const int64 a, const int64 b) {
  return a == b;
}

}  // namespace fletch
