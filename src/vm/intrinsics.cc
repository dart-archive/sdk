// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/intrinsics.h"

#include "src/shared/assert.h"

namespace dartino {

IntrinsicsTable* IntrinsicsTable::default_table_ = NULL;

IntrinsicsTable* IntrinsicsTable::GetDefault() {
  if (default_table_ == NULL) {
    default_table_ = new IntrinsicsTable(
#define ADDRESS_GETTER(name) &Intrinsic_##name,
        INTRINSICS_DO(ADDRESS_GETTER)
#undef ADDRESS_GETTER
            NULL);
  }
  return default_table_;
}

bool IntrinsicsTable::set_from_string(const char* name, void (*ptr)(void)) {
#define SET_INTRINSIC(name_)       \
  if (strcmp(#name_, name) == 0) { \
    intrinsic_##name_##_ = ptr;    \
    return true;                   \
  }
  INTRINSICS_DO(SET_INTRINSIC)
#undef SET_INTRINSIC
  return false;
}

}  // namespace dartino
