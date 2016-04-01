// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Maintains data outside the heap that the garbage collector needs. Because
// the heap is always allocated from a restricted contiguous address area, the
// tables of the metadata can also be contiguous without needing complicated
// mapping.

#ifndef SRC_VM_GC_METADATA_H_
#define SRC_VM_GC_METADATA_H_

#include <stdint.h>

#include "src/vm/object_memory.h"

namespace dartino {

class GCMetadata {
 public:
  static void Setup();
  static void TearDown();

  static const int kCardBits = 7;
  // Number of bytes per remembered-set card.
  static const int kCardSize = 1 << 7;

  static const int kWordShift = (sizeof(uword) == 8 ? 3 : 2);

  // There is a byte per card, and any two byte values would work here.
  static const int kNoNewSpacePointers = 0;
  static const int kNewSpacePointers = 1;  // Actually any non-zero value.

  // One bit per word of mark bits, so the size in bytes is 1/8th of that.
  static const int kMarkBitsShift = 3 + kWordShift;

  static void InitializeStartsForChunk(Chunk* chunk) {
    uword base = chunk->base();
    uword size = (chunk->limit() - base) >> kCardBits;
    base = (base >> kCardBits) + singleton_.starts_bias_;
    memset(reinterpret_cast<uint8*>(base), kNoObjectStart, size);
  }

  static void InitializeRememberedSetForChunk(Chunk* chunk) {
    uword base = chunk->base();
    uword size = (chunk->limit() - base) >> kCardBits;
    base = (base >> kCardBits) + singleton_.remembered_set_bias_;
    memset(reinterpret_cast<uint8*>(base), GCMetadata::kNoNewSpacePointers,
           size);
  }

  static void ClearMarkBitsFor(Chunk* chunk) {
    uword base = chunk->base();
    uword size = (chunk->limit() - base) >> kMarkBitsShift;
    base = (base >> kMarkBitsShift) + singleton_.mark_bits_bias_;
    memset(reinterpret_cast<uint8*>(base), 0, size);
  }

  static uint8* StartsFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardBits) +
                                    singleton_.starts_bias_);
  }

  static uint8* RememberedSetFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardBits) +
                                    singleton_.remembered_set_bias_);
  }

  static bool IsMarked(HeapObject* object) {
    uword address = reinterpret_cast<uword>(object);
    address = (singleton_.mark_bits_bias_ + (address >> kMarkBitsShift)) & ~3;
    uint32 mask = 1 << ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
    return (*reinterpret_cast<uint32*>(address) & mask) != 0;
  }

  // Marks all the bits (1 bit per word) that correspond to a live object.
  static void Mark(HeapObject* object, size_t size) {
    ASSERT(size >= sizeof(uword));
    int mask_shift = ((reinterpret_cast<uword>(object) >> kWordShift) & 31);
    size_t size_in_words = size >> kWordShift;
    // Jump to the slow case routine to handle crossing an int32_t boundary.
    if (mask_shift + size_in_words > 31) return SlowMark(object, size);

    uword address = (singleton_.mark_bits_bias_ +
                     (reinterpret_cast<uword>(object) >> kMarkBitsShift)) &
                    ~3;
    uint32 mask = ((1 << size_in_words) - 1) << mask_shift;
    *reinterpret_cast<uint32*>(address) |= mask;
  }

  static int heap_allocation_arena() {
    return singleton_.heap_allocation_arena_;
  }

  static uword lowest_old_space_address() { return singleton_.lowest_address_; }

  static uword heap_extent() { return singleton_.heap_extent_; }

  static uword remembered_set_bias() { return singleton_.remembered_set_bias_; }

  // Unaligned, so cannot clash with a real object start.
  static const int kNoObjectStart = 2;

  // We need to track the start of an object for each card, so that we can
  // iterate just part of the heap.  This does that.  The cards are less than
  // 256 bytes large (see the assert below), so writing the last byte of the
  // object start address is enough to uniquely identify the address.
  inline static void RecordStart(uword address) {
    uint8* start = StartsFor(address);
    ASSERT(kCardBits <= 8);
    *start = static_cast<uint8>(address);
  }

  inline static void InsertIntoRememberedSet(uword address) {
    address >>= kCardBits;
    address += singleton_.remembered_set_bias_;
    *reinterpret_cast<uint8*>(address) = kNewSpacePointers;
  }

  inline static bool IsMarkedDirty(uword address) {
    address >>= kCardBits;
    address += singleton_.remembered_set_bias_;
    return *reinterpret_cast<uint8*>(address) != kNoNewSpacePointers;
  }

 private:
  GCMetadata() {}
  ~GCMetadata() {}

  static GCMetadata singleton_;

  static void SlowMark(HeapObject* object, size_t size);

  // We have two bytes per card: one for remembered set, and one for object
  // start offset.
  static const int kMetadataBytes = 2;

  // Heap metadata (remembered set etc.).
  uword lowest_address_;
  uword heap_extent_;
  uword number_of_cards_;
  int heap_allocation_arena_;
  unsigned char* metadata_;
  unsigned char* remembered_set_;
  unsigned char* object_starts_;
  uint32* mark_bits_;
  uword starts_bias_;
  uword remembered_set_bias_;
  uword mark_bits_bias_;
};

}  // namespace dartino

#endif  // SRC_VM_GC_METADATA_H_
