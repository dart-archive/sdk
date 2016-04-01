// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/gc_metadata.h"

#include <stdio.h>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/vm/object.h"

namespace dartino {

GCMetadata GCMetadata::singleton_;

void GCMetadata::TearDown() {
  uword mark_bits_size = singleton_.heap_extent_ >> kMarkBitsShift;
  Platform::FreePages(
      singleton_.metadata_,
      singleton_.number_of_cards_ * kMetadataBytes + mark_bits_size);
}

void GCMetadata::Setup() {
  const int kRanges = 4;
  Platform::HeapMemoryRange ranges[kRanges];
  int range_count = Platform::GetHeapMemoryRanges(ranges, kRanges);
  ASSERT(range_count > 0);

  // Find the largest area.
  int largest_index = 0;
  uword largest_size = ranges[0].size;
  for (int i = 1; i < range_count; i++) {
    if (ranges[i].size > largest_size) {
      largest_size = ranges[i].size;
      largest_index = i;
    }
  }

  singleton_.heap_allocation_arena_ = 1 << largest_index;

  singleton_.lowest_address_ =
      reinterpret_cast<uword>(ranges[largest_index].address);
  uword size = ranges[largest_index].size;
  singleton_.heap_extent_ = size;

  singleton_.number_of_cards_ = size >> kCardBits;

  uword mark_bits_size = size >> kMarkBitsShift;

  singleton_.metadata_ =
      reinterpret_cast<unsigned char*>(Platform::AllocatePages(
          singleton_.number_of_cards_ * kMetadataBytes + mark_bits_size,
          Platform::kAnyArena));
  singleton_.remembered_set_ = singleton_.metadata_;
  singleton_.object_starts_ =
      singleton_.metadata_ + singleton_.number_of_cards_;
  singleton_.mark_bits_ = reinterpret_cast<uint32*>(
      singleton_.metadata_ + 2 * singleton_.number_of_cards_);

  uword start = reinterpret_cast<uword>(singleton_.object_starts_);
  uword lowest = singleton_.lowest_address_;
  uword shifted = lowest >> kCardBits;
  singleton_.starts_bias_ = start - shifted;

  start = reinterpret_cast<uword>(singleton_.remembered_set_);
  singleton_.remembered_set_bias_ = start - shifted;

  shifted = lowest >> kMarkBitsShift;
  start = reinterpret_cast<uword>(singleton_.mark_bits_);
  singleton_.mark_bits_bias_ = start - shifted;
}

// Mark an object whose mark bits cross a 32 bit boundary.
void GCMetadata::SlowMark(HeapObject* object, size_t size) {
  int mask_shift = ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
  uint32* bits = reinterpret_cast<uint32*>((singleton_.mark_bits_bias_ +
                   (reinterpret_cast<uword>(object) >> kMarkBitsShift)) &
                  ~3);
  uint32 mask = 0xffffffffu << mask_shift;
  *bits |= mask;

  bits++;
  uint32 words = size >> kWordShift;
  for (words -= 32 - mask_shift; words >= 32; words -= 32) {
    *bits = 0xffffffffu;
    bits++;
  }
  *bits |= (1 << words) - 1;
}

}  // namespace dartino
