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
  Platform::FreePages(singleton_.metadata_, singleton_.metadata_size_);
}

void GCMetadata::Setup() { singleton_.SetupSingleton(); }

void GCMetadata::SetupSingleton() {
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

  heap_allocation_arena_ = 1 << largest_index;

  lowest_address_ = reinterpret_cast<uword>(ranges[largest_index].address);
  uword size = ranges[largest_index].size;
  heap_extent_ = size;

  number_of_cards_ = size >> kCardSizeLog2;

  uword mark_bits_size = size >> kMarkBitsShift;
  uword mark_stack_overflow_bits_size = size >> kCardSizeInBitsLog2;

  uword page_type_size_ = size >> Platform::kPageBits;

  // We have two bytes per card: one for remembered set, and one for object
  // start offset.
  metadata_size_ =
      Utils::RoundUp(number_of_cards_ * 2 + mark_bits_size +
                         mark_stack_overflow_bits_size + page_type_size_,
                     Platform::kPageSize);

  metadata_ = reinterpret_cast<unsigned char*>(
      Platform::AllocatePages(metadata_size_, Platform::kAnyArena));
  remembered_set_ = metadata_;
  object_starts_ = metadata_ + number_of_cards_;
  mark_bits_ = reinterpret_cast<uint32*>(metadata_ + 2 * number_of_cards_);
  mark_stack_overflow_bits_ =
      reinterpret_cast<uint8_t*>(mark_bits_) + mark_bits_size;
  page_type_bytes_ = mark_stack_overflow_bits_ + mark_stack_overflow_bits_size;

  memset(page_type_bytes_, kUnknownSpacePage, page_type_size_);

  uword start = reinterpret_cast<uword>(object_starts_);
  uword lowest = lowest_address_;
  uword shifted = lowest >> kCardSizeLog2;
  starts_bias_ = start - shifted;

  start = reinterpret_cast<uword>(remembered_set_);
  remembered_set_bias_ = start - shifted;

  shifted = lowest >> kMarkBitsShift;
  start = reinterpret_cast<uword>(mark_bits_);
  mark_bits_bias_ = start - shifted;

  shifted = lowest >> kCardSizeInBitsLog2;
  start = reinterpret_cast<uword>(mark_stack_overflow_bits_);
  overflow_bits_bias_ = start - shifted;
}

uword GCMetadata::ObjectAddressFromStart(uword card, uint8 start) {
  uword object_address = (card & ~0xff) | start;
  ASSERT(object_address >> GCMetadata::kCardSizeLog2 ==
         card >> GCMetadata::kCardSizeLog2);
  return object_address;
}

// Mark all bits of an object whose mark bits cross a 32 bit boundary.
void GCMetadata::SlowMark(HeapObject* object, size_t size) {
  int mask_shift = ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
  uint32* bits = MarkBitsFor(object);

  uint32 mask = 0xffffffffu << mask_shift;
  *bits |= mask;

  bits++;
  uint32 words = size >> kWordShift;
  for (words -= 32 - mask_shift; words >= 32; words -= 32)
    *bits++ = 0xffffffffu;
  *bits |= (1 << words) - 1;
}

void GCMetadata::MarkStackOverflow(HeapObject* object) {
  uword address = object->address();
  uint8* overflow_bits = OverflowBitsFor(address);
  *overflow_bits |= 1 << ((address >> kCardSizeLog2) & 7);
  // We can have a mark stack overflow in new-space where we do not normally
  // maintain object starts. By updating the object starts for this card we
  // can be sure that the necessary objects in this card are walkable.
  uint8* start = StartsFor(address);
  ASSERT(kCardSizeLog2 <= 8);
  uint8 low_byte = static_cast<uint8>(address);
  // We only overwrite the object start if we didn't have object start info
  // before or if this object is before the previous object start, which
  // would mean we would not scan the necessary object.
  if (*start == kNoObjectStart || *start > low_byte) *start = low_byte;
}

}  // namespace dartino
