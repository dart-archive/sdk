// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SORT_H_
#define SRC_VM_SORT_H_

#include "src/shared/assert.h"

namespace dartino {

typedef bool (*VoidCompare)(uint8* a, uint8* b);

void VoidSort(uint8* buffer, size_t elements, size_t element_size,
              VoidCompare compare);

template <typename T>
struct SortType {
  typedef bool (*Compare)(const T& a, const T& b);
  typedef bool (*PointerCompare)(const T* a, const T* b);
};

template <typename T>
void Sort(T* from, size_t elements, typename SortType<T>::Compare compare) {
  VoidSort(reinterpret_cast<uint8*>(from), elements, sizeof(T),
           reinterpret_cast<VoidCompare>(compare));
}

template <typename T>
void Sort(T* from, size_t elements,
          typename SortType<T>::PointerCompare compare) {
  VoidSort(reinterpret_cast<uint8*>(from), elements, sizeof(T),
           reinterpret_cast<VoidCompare>(compare));
}

}  // namespace dartino

#endif  // SRC_VM_SORT_H_
