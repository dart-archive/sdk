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
  Platform::FreePages(singleton_.metadata_,
                      singleton_.number_of_cards_ * kMetadataBytes);
}

void GCMetadata::Setup() {
  const int kRanges = 4;
  Platform::HeapMemoryRange ranges[kRanges];
  int range_count = Platform::GetHeapMemoryRanges(ranges, kRanges);
  ASSERT(range_count > 0);

  // Find the largest area
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

  singleton_.metadata_ =
      reinterpret_cast<unsigned char*>(Platform::AllocatePages(
          singleton_.number_of_cards_ * kMetadataBytes, Platform::kAnyArena));
  singleton_.remembered_set_ = singleton_.metadata_;
  singleton_.object_starts_ =
      singleton_.metadata_ + singleton_.number_of_cards_;

  uword start = reinterpret_cast<uword>(singleton_.object_starts_);
  uword lowest = singleton_.lowest_address_;
  uword shifted = lowest >> kCardBits;
  singleton_.starts_bias_ = start - shifted;

  start = reinterpret_cast<uword>(singleton_.remembered_set_);
  singleton_.remembered_set_bias_ = start - shifted;
}

}  // namespace dartino
