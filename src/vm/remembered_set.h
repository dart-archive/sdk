// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_REMEMBERED_SET_H_
#define SRC_VM_REMEMBERED_SET_H_

#include "src/vm/object_memory.h"

namespace dartino {

class GCMetadata {
 public:
  static void Setup();
  static void TearDown();

  static const int kCardBits = 7;
  // Number of bytes per remembered-set card.
  static const int kCardSize = 1 << 7;

  // There is a byte per card, and any two byte values would work here.
  static const int kNoNewSpacePointers = 0;
  static const int kNewSpacePointers = 1;  // Actually any non-zero value.

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

  static uint8* StartsFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardBits) +
                                    singleton_.starts_bias_);
  }

  static uint8* RememberedSetFor(uword address) {
    return reinterpret_cast<uint8*>((address >> kCardBits) +
                                    singleton_.remembered_set_bias_);
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

 private:
  GCMetadata() {}
  ~GCMetadata() {}

  static GCMetadata singleton_;

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
  uword starts_bias_;
  uword remembered_set_bias_;
};

}  // namespace dartino

#endif  // SRC_VM_REMEMBERED_SET_H_
