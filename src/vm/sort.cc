// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/sort.h"

#include <stddef.h>

#include "src/shared/assert.h"
#include "src/shared/random.h"

namespace dartino {

void InsertionSort(uint8* array, size_t elements, size_t element_size,
                   VoidCompare compare) {
  uint8 temp_buffer[128];
  ASSERT(element_size <= 128);
  uint8* end = array + elements * element_size;
  for (uint8* p = array + element_size; p < end; p += element_size) {
    if (!compare(p, p - element_size)) continue;  // Already in order.

    // Find insertion point.
    uint8* q;
    for (q = p; q > array; q -= element_size) {
      if (!compare(p, q - element_size)) break;
    }
    memcpy(temp_buffer, p, element_size);
    memmove(q + element_size, q, p - q);
    memcpy(q, temp_buffer, element_size);
  }
}

static void Swap(uint8* a, uint8* b, size_t element_size) {
  for (unsigned i = 0; i < element_size; i += sizeof(int)) {
    int t = *reinterpret_cast<int*>(a);
    *reinterpret_cast<int*>(a) = *reinterpret_cast<int*>(b);
    *reinterpret_cast<int*>(b) = t;
    a += sizeof(int);
    b += sizeof(int);
  }
}

static const size_t kMinElementsForQuickSort = 10;

static size_t MaskLessThan(size_t max) {
  max &= 0xffffffffu;

  // Smear the bits.
  max |= max >> 16;
  max |= max >> 8;
  max |= max >> 4;
  max |= max >> 2;
  max |= max >> 1;
  return max >> 1;
}

static RandomXorShift* random = NULL;

// Pick median of 3.  First the candidates are placed as 1.........23.  On
// exit they have been sorted into S(mallest), M(edian) and (Largest) and they
// are placed S..........LM.  This way, S and L provide the sentinels needed
// and the pivot is placed in the top partition.
void ChoosePivot(uint8* left, uint8* pivot, size_t element_size,
                 VoidCompare compare, size_t mask) {
  if (random == NULL) random = new RandomXorShift();
  uint8* one = left + (1 + (random->NextUInt32() & mask)) * element_size;
  uint8* two = left + (1 + (random->NextUInt32() & mask)) * element_size;
  uint8* three = left + (1 + (random->NextUInt32() & mask)) * element_size;

  // Move three pivot candidates to the ends.
  Swap(left, one, element_size);
  Swap(pivot, two, element_size);
  Swap(pivot - element_size, three, element_size);
  uint8* right = pivot - element_size;

  // Sort three pivot candidates.
  if (compare(right, pivot)) Swap(right, pivot, element_size);
  if (compare(pivot, left)) Swap(pivot, left, element_size);
  if (compare(right, pivot)) Swap(right, pivot, element_size);
}

void VoidSort(uint8* start, size_t elements, size_t element_size,
              VoidCompare compare) {
  while (elements >= kMinElementsForQuickSort) {
    size_t mask = MaskLessThan(elements - 3);
    uint8* pivot = start + (elements - 1) * element_size;
    ChoosePivot(start, pivot, element_size, compare, mask);
    uint8* left = start;  // Immediately incremented so it skips the sentinel.

    // Kept in sync with right, avoids division by element_size.
    int partition_index = elements - 2;

    // Right is immediately decremented and so skips the right sentinel.
    uint8* right = pivot - element_size;

    // Assert that pivot was correctly picked and sentinels are in place.
    ASSERT(!compare(right, pivot) && !compare(pivot, left));
    ASSERT(start + partition_index * element_size == right);  // In sync.

    // Double index Hoare partition with the pivot on the right.
    while (true) {
      do {
        right -= element_size;
        partition_index--;
        ASSERT(start <= right && right < pivot);
      } while (compare(pivot, right));
      do {
        left += element_size;
        ASSERT(start <= left && left < pivot);
      } while (compare(left, pivot));
      if (left >= right) break;
      Swap(left, right, element_size);
    }
    uint8* partition = right + element_size;
    partition_index++;
    ASSERT(start + partition_index * element_size == partition);  // In sync.

    // Recurse on short interval to limit recursion depth.
    if (pivot - partition < partition - start) {
      VoidSort(partition, elements - partition_index, element_size, compare);
      elements = partition_index;
    } else {
      VoidSort(start, partition_index, element_size, compare);
      start = partition;
      elements -= partition_index;
    }
  }
  InsertionSort(start, elements, element_size, compare);
}

}  // namespace dartino
